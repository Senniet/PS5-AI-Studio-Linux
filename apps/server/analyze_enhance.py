#!/usr/bin/env python3
"""Content-aware photo diagnostics and conservative enhancement recommendations."""
import sys,json
from PIL import Image,ImageOps,ImageFilter,ImageStat,ImageChops
opened=Image.open(sys.argv[1])
source_format=opened.format or "unknown"
source=ImageOps.exif_transpose(opened)
source_width,source_height=source.size
source_pixels=source_width*source_height
im=source.convert("RGB")
im.thumbnail((900,900))
gray=im.convert("L")
hist=gray.histogram(); total=sum(hist)
def pct(q):
 target=total*q; acc=0
 for i,n in enumerate(hist):
  acc+=n
  if acc>=target:return i/255
 return 1.0
mean=ImageStat.Stat(gray).mean[0]/255
p05,p50,p95=pct(.05),pct(.50),pct(.95)
dark=sum(hist[:41])/total; bright=sum(hist[240:])/total
contrast=p95-p05
hsv=im.convert("HSV"); sat=ImageStat.Stat(hsv).mean[1]/255
edges=gray.filter(ImageFilter.FIND_EDGES); edge_stat=ImageStat.Stat(edges)
edge=(edge_stat.mean[0]/255)**2
blur=gray.filter(ImageFilter.GaussianBlur(radius=1.2))
noise=ImageStat.Stat(ImageChops.difference(gray,blur)).mean[0]/255
r={"exposure":0.0,"highlights":0,"shadows":0,"contrast":100,"saturation":100,"sharpness":100,"denoise":0,"retinexformer":False,"retinexStrength":65,"retinexTile":128,"retinexReason":"Niet nodig op basis van de gemeten belichting.","reasons":[],"metrics":{}}
if mean<.34 or dark>.28:
 # Stronger shadow recovery for genuinely underexposed images; preserve highlight headroom.
 r["exposure"]=0.0
 r["shadows"]=int(min(92,max(78,dark*112)))
 r["retinexformer"]=False
 r["retinexStrength"]=35
 r["retinexReason"]="Niet automatisch ingeschakeld. Eerst de gerichte tooncurve en detailverbetering proberen."
 r["reasons"].append("Sterke schaduwcorrectie wordt voorgesteld om details in donkere partijen duidelijker zichtbaar te maken, met bescherming van de lichte delen.")
elif mean>.78 or bright>.18:
 r["exposure"]=round(-min(.45,max(.1,(mean-.68)*.9)),1);r["highlights"]=int(min(45,max(8,bright*90)))
 r["reasons"].append("De foto is aan de lichte kant; highlights en belichting worden voorzichtig getemperd.")
# In a strongly underexposed image, increasing global contrast usually crushes shadow detail.
if mean<.25 and dark>.45:
 r["contrast"]=108
 r["reasons"].append("Een kleine contrastverhoging houdt het beeld krachtiger nadat de schaduwen zijn opgehaald.")
elif contrast<.32:
 r["contrast"]=int(min(112,max(103,100+(.32-contrast)*35)))
 r["reasons"].append("Het gemeten toonbereik is beperkt; alleen een kleine contrastcorrectie is veilig.")
elif contrast>.88:
 r["contrast"]=int(max(92,100-(contrast-.82)*25))
 r["reasons"].append("Het contrast is al sterk; extra contrast wordt afgeraden.")
# Color statistics in deep shadows are unreliable; defer color decisions until exposure is corrected.
if mean<.25 or dark>.45:
 r["saturation"]=100
 r["reasons"].append("Kleurverzadiging wordt niet automatisch aangepast: bij deze sterke onderbelichting is de kleurmeting onvoldoende betrouwbaar.")
elif sat<.16:
 r["saturation"]=int(min(118,max(105,100+(.19-sat)*100)))
 r["reasons"].append("De kleuren lijken wat flets; alleen een kleine verzadigingscorrectie wordt voorgesteld.")
elif sat>.58:
 r["saturation"]=95
 r["reasons"].append("De kleuren zijn al sterk verzadigd; iets terugnemen voorkomt onnatuurlijke kleuren.")
# A low edge score in a dark frame is not proof of blur. Sharpening can amplify noise and compression.
if mean<.34 or dark>.28:
 r["sharpness"]=150
 r["denoise"]=12
 r["reasons"].append("Na het ophalen van de schaduwen wordt gecontroleerde verscherping toegepast, met lichte ruisonderdrukking om korrel niet onnodig te versterken.")
elif edge<.012 and noise<.035:
 r["sharpness"]=108
 r["reasons"].append("Er zijn weinig fijne randen en weinig gemeten ruis; een heel lichte verscherping kan helpen.")
elif edge>.11:
 r["reasons"].append("Er is al veel lokaal detail; extra verscherping kan artefacten versterken.")
if noise>.075:
 r["denoise"]=int(min(35,max(10,(noise-.05)*250)))
 r["reasons"].append("Er is relatief veel fijne beeldruis gemeten; lichte ruisonderdrukking wordt voorgesteld.")
if r["retinexformer"] and noise>.055:
 r["denoise"]=max(r["denoise"],12)
 r["reasons"].append("Na AI-herstel is extra controle op zichtbare ruis verstandig.")
if not r["reasons"]:r["reasons"].append("De foto is qua licht, contrast en kleur redelijk in balans. Grote correcties zijn niet nodig.")
scene="low-light" if mean<.34 or dark>.28 else "bright" if mean>.78 or bright>.18 else "low-contrast" if contrast<.32 else "high-detail" if edge>.11 else "balanced"
r["metrics"]={"brightness":round(mean,3),"shadows":round(dark*100,1),"clippedHighlights":round(bright*100,1),"dynamicRange":round(contrast,3),"saturation":round(sat,3),"detailScore":round(edge,4),"noiseEstimate":round(noise,4),"width":source_width,"height":source_height,"analysisWidth":im.width,"analysisHeight":im.height,"megapixels":round(source_pixels/1_000_000,2),"aspectRatio":round(source_width/source_height,3) if source_height else None,"format":source_format,"scene":scene}
print(json.dumps(r))