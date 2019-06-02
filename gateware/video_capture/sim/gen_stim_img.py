from PIL import Image, ImageDraw, ImageFont
 
fnt = ImageFont.truetype('DejaVuSansMono.ttf', 72)
fnt_sm = ImageFont.truetype('DejaVuSansMono.ttf', 24)

for i in range(256):
    img = Image.new('RGB', (1280, 720), color = (58, 110, 165))
    d = ImageDraw.Draw(img)
    d.text((60,60), ('Stimulus Image No. %08d'%i), font=fnt, fill=(255, 255, 0))
    d.text((10+0*1280/4,300), ('%08d'%i), font=fnt_sm, fill=(255, 255, 0))
    d.text((10+1*1280/4,300), ('%08d'%i), font=fnt_sm, fill=(255, 255, 0))
    d.text((10+2*1280/4,300), ('%08d'%i), font=fnt_sm, fill=(255, 255, 0))
    d.text((10+3*1280/4,300), ('%08d'%i), font=fnt_sm, fill=(255, 255, 0))
    img.save('stim_img_%08d.png' % i)
    fp = open('stim_img_%08d.raw' % i,'wb')
    fp.write(img.tobytes())
    fp.close()