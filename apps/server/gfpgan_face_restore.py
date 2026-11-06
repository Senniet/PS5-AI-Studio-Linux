#!/usr/bin/env python3
"""YuNet face detection/alignment + GFPGAN MNN/Vulkan restoration."""
import json, os, signal, subprocess, sys, tempfile, time
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageOps

active_runner = None
def stop_runner(signum, frame):
    global active_runner
    if active_runner is not None and active_runner.poll() is None:
        try: os.killpg(active_runner.pid, signal.SIGTERM)
        except ProcessLookupError: pass
    raise SystemExit(128 + signum)
signal.signal(signal.SIGTERM, stop_runner)

def save_output(bgr, alpha, output_path):
    final = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
    if alpha is not None: final.putalpha(alpha)
    final.save(output_path, format='PNG', optimize=True)

def main():
    if len(sys.argv) != 7:
        raise SystemExit('usage: gfpgan_face_restore.py input output model runner detector strength')
    source_path, output_path, model_path, runner, detector_path = sys.argv[1:6]
    strength = max(0.0, min(1.0, float(sys.argv[6]) / 100.0))
    started = time.monotonic()
    if not all(Path(p).is_file() for p in (source_path, model_path, runner, detector_path)):
        raise RuntimeError('GFPGAN-model, runner of YuNet-detector ontbreekt')
    # OpenCV reads EXIF orientation inconsistently across builds; normalize with Pillow first.
    with Image.open(source_path) as pil:
        pil = ImageOps.exif_transpose(pil)
        alpha = pil.getchannel('A') if pil.mode == 'RGBA' else None
        rgb = pil.convert('RGB')
        bgr = cv2.cvtColor(np.asarray(rgb), cv2.COLOR_RGB2BGR)
    height, width = bgr.shape[:2]
    if width * height > 40_000_000:
        raise RuntimeError('Afbeelding is groter dan 40 megapixel')
    scale = min(640.0 / width, 640.0 / height)
    rw, rh = max(1, round(width * scale)), max(1, round(height * scale))
    resized = cv2.resize(bgr, (rw, rh), interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_CUBIC)
    px, py = (640-rw)//2, (640-rh)//2
    canvas = np.zeros((640,640,3), dtype=np.uint8)
    canvas[py:py+rh, px:px+rw] = resized
    detector = cv2.FaceDetectorYN_create(detector_path, '', (640,640), 0.65, 0.30, 5000)
    _, detections = detector.detect(canvas)
    if detections is None or len(detections) == 0:
        save_output(bgr, alpha, output_path)
        print(json.dumps({'ok':True,'faces':0,'message':'Geen gezicht gevonden; afbeelding ongewijzigd opgeslagen.','backend':'YuNet CPU + GFPGAN MNN Vulkan'}))
        return
    template = np.array([[192.98138,239.94708],[318.90277,240.19360],[256.63416,314.01935],[201.26117,371.41043],[313.08905,371.15118]], dtype=np.float32)
    faces=[]
    for det in detections:
        x,y,w,h = map(float, det[:4])
        if min(w,h) < 24: continue
        points = det[4:14].reshape(5,2).astype(np.float32)
        points[:,0] = (points[:,0]-px)/scale
        points[:,1] = (points[:,1]-py)/scale
        x0,y0 = (x-px)/scale,(y-py)/scale
        fw,fh=w/scale,h/scale
        if x0+fw<0 or y0+fh<0 or x0>width or y0>height: continue
        matrix,_ = cv2.estimateAffinePartial2D(points, template, method=cv2.LMEDS)
        if matrix is None: continue
        aligned = cv2.warpAffine(bgr, matrix, (512,512), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT_101)
        face_rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB).astype(np.float32)
        tensor = (face_rgb / 127.5 - 1.0).transpose(2,0,1).astype(np.float32)
        faces.append((matrix, tensor, float(det[14])))
    if not faces:
        save_output(bgr, alpha, output_path)
        print(json.dumps({'ok':True,'faces':0,'message':'Geen bruikbaar gezicht gevonden; afbeelding ongewijzigd opgeslagen.','backend':'YuNet CPU + GFPGAN MNN Vulkan'}))
        return
    with tempfile.TemporaryDirectory(prefix='gfpgan-') as td:
        inp, out = Path(td)/'faces.f32', Path(td)/'restored.f32'
        with inp.open('wb') as f:
            for _,tensor,_ in faces: tensor.tofile(f)
        global active_runner
        active_runner = subprocess.Popen([runner, model_path, str(inp), str(out), str(len(faces))], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try: runner_out, runner_err = active_runner.communicate(timeout=900)
        except subprocess.TimeoutExpired:
            os.killpg(active_runner.pid, signal.SIGKILL)
            runner_out, runner_err = active_runner.communicate()
            raise RuntimeError('GFPGAN Vulkan-runtime timeout na 15 minuten')
        proc = type('RunnerResult', (), {'stdout':runner_out,'stderr':runner_err,'returncode':active_runner.returncode})()
        active_runner = None
        if proc.returncode != 0:
            raise RuntimeError((proc.stderr or proc.stdout or 'GFPGAN Vulkan-runtime mislukt').strip()[-1800:])
        values = np.fromfile(out, dtype=np.float32)
        expected = len(faces)*3*512*512
        if values.size != expected or not np.isfinite(values).all():
            raise RuntimeError('GFPGAN gaf ongeldige uitvoerdata terug')
        restored_faces = values.reshape(len(faces),3,512,512)
        result = bgr.astype(np.float32)
        for (matrix,_,score), restored in zip(faces, restored_faces):
            rgb_out = np.clip((restored.transpose(1,2,0)+1.0)*127.5,0,255).astype(np.uint8)
            face_bgr = cv2.cvtColor(rgb_out, cv2.COLOR_RGB2BGR)
            inverse = cv2.invertAffineTransform(matrix)
            warped = cv2.warpAffine(face_bgr, inverse, (width,height), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
            mask = np.zeros((512,512), dtype=np.float32)
            cv2.ellipse(mask,(256,270),(190,220),0,0,360,1.0,-1)
            mask = cv2.GaussianBlur(mask,(0,0),18)
            full_mask = cv2.warpAffine(mask, inverse, (width,height), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
            blend = np.clip(full_mask*strength,0,1)[...,None]
            result = result*(1-blend) + warped.astype(np.float32)*blend
        result = np.clip(result,0,255).astype(np.uint8)
        out_rgb = cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
        final = Image.fromarray(out_rgb)
        if alpha is not None:
            final.putalpha(alpha)
        final.save(output_path, format='PNG', optimize=True)
    print(json.dumps({'ok':True,'faces':len(faces),'scores':[round(x[2],3) for x in faces],'strength':round(strength,2),'backend':'YuNet OpenCV DNN CPU + GFPGAN MNN Vulkan FP32','elapsedSeconds':round(time.monotonic()-started,2),'runtimeLog':proc.stdout.strip()[-600:]}))

if __name__ == '__main__':
    try: main()
    except Exception as exc:
        print(json.dumps({'ok':False,'error':str(exc)}), file=sys.stderr)
        raise
