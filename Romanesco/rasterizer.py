from cefpython3 import cefpython
import re
import os
import sys
from math import *
import cStringIO
import StringIO
from PIL import Image
import errno

import threading, time

### --- Database model --- ###

from mongoengine import *

connect('Romanesco')

class AreaToUpdate(Document):
    planetX = DecimalField()
    planetY = DecimalField()
    box = PolygonField()

    rType = StringField(default='AreaToUpdate')
    # areas = ListField(ReferenceField('Area'))

    meta = {
        'indexes': [[ ("planetX", 1), ("planetY", 1), ("box", "2dsphere"), ("date", 1) ]]
    }

### --- Rasterizer --- ###

state = 'page not loaded' # 'image saved' 'image loaded'
area = None

# -- save image -- #

def roundToLowerMultiple(x, m):
    return int(floor(x/float(m))*m)

# warning: difference between ceil(x/m)*m and floor(x/m)*(m+1)
def roundToGreaterMultiple(x, m):
    return int(ceil(x/float(m))*m)

def saveImage(image, xf, yf):
    x = int(xf)
    y = int(yf)

    start = time.time()

    width = int(image.size[0])
    height = int(image.size[1])

    l = roundToLowerMultiple(x, 1000)
    t = roundToLowerMultiple(y, 1000)
    r = roundToLowerMultiple(x+width, 1000)+1000
    b = roundToLowerMultiple(y+height, 1000)+1000

    imageOnGrid25x = roundToLowerMultiple(x, 25)
    imageOnGrid25y = roundToLowerMultiple(y, 25)
    imageOnGrid25width = roundToGreaterMultiple(x+width, 25)-imageOnGrid25x
    imageOnGrid25height = roundToGreaterMultiple(y+height, 25)-imageOnGrid25y

    # debug

    # image.save('media/rasters/image.png')

    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print 'original rect'
    # print x
    # print y
    # print width
    # print height
    # print 'rounded rect'
    # print l
    # print t
    # print r
    # print b

    # print 'image size:'
    # print image.size[0]
    # print image.size[1]

    # print 'big image:'
    # print imageOnGrid25x
    # print imageOnGrid25y
    # print imageOnGrid25width
    # print imageOnGrid25height

    # try:
    # imageOnGrid25 = Image.new("RGBA", (1000, 1000))
    imageOnGrid25 = Image.new("RGBA", (imageOnGrid25width, imageOnGrid25height))

    for xi in range(l,r,1000):
        for yi in range(t,b,1000):

            x1 = int(xi/1000)
            y1 = int(yi/1000)

            x5 = roundToLowerMultiple(x1, 5)
            y5 = roundToLowerMultiple(y1, 5)

            x25 = roundToLowerMultiple(x1, 25)
            y25 = roundToLowerMultiple(y1, 25)

            rasterPath = 'media/rasters/zoom100/' + str(x25) + ',' + str(y25) + '/' + str(x5) + ',' + str(y5) + '/'

            try:
                os.makedirs(rasterPath)
            except OSError as exception:
                if exception.errno != errno.EEXIST:
                    raise

            rasterName = rasterPath + str(x1) + "," + str(y1) + ".png"

            try:
                # raster = Image(filename=rasterName)       # Wand version
                raster = Image.open(rasterName)             # Pillow version
            except IOError:
                # raster = Image(width=1000, height=1000)   # Wand version
                raster = Image.new("RGBA", (1000, 1000))    # Pillow version
                
            left = max(xi,x)
            right = min(xi+1000,x+width)
            top = max(yi,y)
            bottom = min(yi+1000,y+height)

            # print '-----'
            # print '-----'
            # print 'raster pos:'
            # print xi
            # print yi
            
            # print 'rectangle cutted:'
            # print left
            # print top
            # print right
            # print bottom

            # print 'width, height:'
            # print right-left
            # print bottom-top

            # print 'sub image rect:'
            # print left-x
            # print top-y
            # print right-x
            # print bottom-y
            
            subImage = image.crop((left-x, top-y, right-x, bottom-y))

            # print 'posInRaster:'
            # print left-xi
            # print top-yi
            
            # print 'sub image size:'
            # print subImage.size[0]
            # print subImage.size[1]

            raster.paste(subImage, (left-xi, top-yi))
            raster.save(rasterName)

            left = max(xi,imageOnGrid25x)
            right = min(xi+1000,imageOnGrid25x+imageOnGrid25width)
            top = max(yi,imageOnGrid25y)
            bottom = min(yi+1000,imageOnGrid25y+imageOnGrid25height)

            # subImage.save('media/rasters/subimage_' + str(x1) + ',' + str(y1) + '.png')
            # print 'sub imageOnGrid25 in global coordinates:'
            # print left
            # print top
            # print right
            # print bottom
            # print 'in raster100 coordinates:'
            # print left-xi
            # print top-yi
            # print 'in imageOnGrid25 coordinates:'
            # print left-imageOnGrid25x
            # print top-imageOnGrid25y

            subRaster = raster.crop((left-xi, top-yi, right-xi, bottom-yi))
            imageOnGrid25.paste(subRaster, (left-imageOnGrid25x, top-imageOnGrid25y))
    
    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print 'raster20:'

    l = roundToLowerMultiple(x, 5000)
    t = roundToLowerMultiple(y, 5000)
    r = roundToLowerMultiple(x+width, 5000)+5000
    b = roundToLowerMultiple(y+height, 5000)+5000

    for xi in range(l,r,5000):
        for yi in range(t,b,5000):

            x1 = int(xi/1000)
            y1 = int(yi/1000)

            x5 = roundToLowerMultiple(x1, 5)
            y5 = roundToLowerMultiple(y1, 5)

            x25 = roundToLowerMultiple(x1, 25)
            y25 = roundToLowerMultiple(y1, 25)

            rasterPath = 'media/rasters/zoom20/' + str(x25) + ',' + str(y25) + '/'

            try:
                os.makedirs(rasterPath)
            except OSError as exception:
                if exception.errno != errno.EEXIST:
                    raise

            rasterName = rasterPath + str(x5) + "," + str(y5) + ".png"
    
            try:
                raster = Image.open(rasterName)
            except IOError:
                raster = Image.new("RGBA", (1000, 1000))
            
            left = max(xi,imageOnGrid25x)
            right = min(xi+5000,imageOnGrid25x+imageOnGrid25width)
            top = max(yi,imageOnGrid25y)
            bottom = min(yi+5000,imageOnGrid25y+imageOnGrid25height)

            # print '-----'
            # print '-----'
            # print 'raster pos:'
            # print xi
            # print yi
            # print 'sub imageOnGrid25 in global coordinates:'
            # print left
            # print top
            # print right
            # print bottom
            # print 'in raster20 coordinates:'
            # print (left-xi)/5
            # print (top-yi)/5
            # print 'in imageOnGrid25 coordinates:'
            # print left-imageOnGrid25x
            # print top-imageOnGrid25y

            subImage = imageOnGrid25.crop((left-imageOnGrid25x, top-imageOnGrid25y, right-imageOnGrid25x, bottom-imageOnGrid25y))
            subImageSmall = subImage.resize((subImage.size[0]/5, subImage.size[1]/5), Image.LANCZOS)
            raster.paste(subImageSmall, ((left-xi)/5, (top-yi)/5))
            raster.save(rasterName)
    
    # print '-----'
    # print '-----'
    # print '-----'
    # print '-----'
    # print 'raster4:'

    l = roundToLowerMultiple(x, 25000)
    t = roundToLowerMultiple(y, 25000)
    r = roundToLowerMultiple(x+width, 25000)+25000
    b = roundToLowerMultiple(y+height, 25000)+25000

    for xi in range(l,r,25000):
        for yi in range(t,b,25000):

            x1 = int(xi/1000)
            y1 = int(yi/1000)

            x25 = roundToLowerMultiple(x1, 25)
            y25 = roundToLowerMultiple(y1, 25)

            rasterPath = 'media/rasters/zoom4/'

            try:
                os.makedirs(rasterPath)
            except OSError as exception:
                if exception.errno != errno.EEXIST:
                    raise

            rasterName = rasterPath + str(x25) + "," + str(y25) + ".png"

            try:
                raster = Image.open(rasterName)
            except IOError:
                raster = Image.new("RGBA", (1000, 1000))
                
            left = max(xi,imageOnGrid25x)
            right = min(xi+25000,imageOnGrid25x+imageOnGrid25width)
            top = max(yi,imageOnGrid25y)
            bottom = min(yi+25000,imageOnGrid25y+imageOnGrid25height)

            # print '-----'
            # print '-----'
            # print 'raster pos:'
            # print xi
            # print yi
            # print 'sub imageOnGrid25 in global coordinates:'
            # print left
            # print top
            # print right
            # print bottom
            # print 'in raster4 coordinates:'
            # print (left-xi)/25
            # print (top-yi)/25
            # print 'in imageOnGrid25 coordinates:'
            # print left-imageOnGrid25x
            # print top-imageOnGrid25y

            subImage = imageOnGrid25.crop((left-imageOnGrid25x, top-imageOnGrid25y, right-imageOnGrid25x, bottom-imageOnGrid25y))
            subImageSmall = subImage.resize((subImage.size[0]/25, subImage.size[1]/25), Image.LANCZOS)
            raster.paste(subImageSmall, ((left-xi)/25, (top-yi)/25))
            raster.save(rasterName)

    image.close()

    end = time.time()

    print "Time elapsed: " + str(end - start)
    return

def onLoadEnd(*args, **kwargs):
    print "global on load end"
    global state
    if state == 'page not loaded':
        state = 'page loaded'

def loadArea():
    print 'call js load area'
    browser.GetMainFrame().ExecuteFunction("loadArea", area.to_json())

def loopRasterize():
    browser.GetMainFrame().ExecuteFunction("loopRasterize")

def saveOnServer(imageDataURL, x, y, finished):
    print "saveOnServer: " + str(len(imageDataURL))
    
    if len(imageDataURL)==6:
        import pdb; pdb.set_trace()
    
    imageData = re.search(r'base64,(.*)', imageDataURL).group(1)

    try:
        image = Image.open(StringIO.StringIO(imageData.decode('base64')))               # Pillow version
    except IOError:
        return { 'state': 'error', 'message': 'impossible to read image.'}

    saveImage(image, x, y)
    
    if not finished:
        cefpython.PostTask(cefpython.TID_UI, loopRasterize)
    else:
        global state
        state = 'image saved'
    # browser.NotifyScreenInfoChanged()
    return

# Get the position in project coordinate system of *point* on *planet*
# This is the opposite of projectToPlanetJson
def posOnPlanetToProject(xp, yp, planetX, planetY):
    scale = 1000.0
    x = planetX*360.0+xp
    y = planetY*180.0+yp
    x *= scale
    y *= scale
    return (x,y)

def checkAreasToUpdates():
    global state, area
    print "check area to update: " + state
    sys.stdout.write('\n')
    if state == 'image saved' or state == 'page loaded':
        # global area
        if area:
            area.delete()
            area = None
        area = AreaToUpdate.objects().first()
        if area:
            # global isLoaded, x, y, width, height
            state = 'image loading'
            print "checking areas to update: loading next area"
            planetX = float(area.planetX)
            planetY = float(area.planetY)
            points = area.box['coordinates'][0]
            left = points[0][0]
            top = points[0][1]
            right = points[2][0]
            bottom = points[2][1]

            topLeft = posOnPlanetToProject(left, top, planetX, planetY)
            bottomRight = posOnPlanetToProject(right, bottom, planetX, planetY)

            cefpython.PostTask(cefpython.TID_UI, loadArea)

startTime = time.time()

def main_loop():
    # # cefpython.MessageLoopWork()
    # # time.sleep(0.01)
    # # global isPageLoaded, isSaved, nUpdates
    # global nUpdates
    # nUpdates = nUpdates + 1
    # if nUpdates > 100:
    #     nUpdates = 0
    #     print "check area: " + str(isPageLoaded) + ", " + str(isSaved)
    #     checkAreasToUpdates()
    # threading.Timer(0.01, main_loop).start()
    print time.time() - startTime
    checkAreasToUpdates()
    threading.Timer(1, main_loop).start()


### --- CEF --- ###

settings = {
        "multi_threaded_message_loop": False,
        "log_severity": cefpython.LOGSEVERITY_INFO, # LOGSEVERITY_VERBOSE
        #"log_file": GetApplicationPath("debug.log"), # Set to "" to disable.
        "release_dcheck_enabled": True, # Enable only when debugging.
        # This directories must be set on Linux
        # "locale": "en",
        "locales_dir_path": cefpython.GetModuleDirectory()+"/locales",
        "resources_dir_path": cefpython.GetModuleDirectory()+"/Resources",
        "browser_subprocess_path": "%s/%s" % (
            cefpython.GetModuleDirectory(), "subprocess")
    }

class ClientHandler:
    """A client handler is required for the browser to do built in callbacks back into the application."""
    browser = None

    def __init__(self, browser):
        self.browser = browser

    def OnPaint(self, browser, paintElementType, dirtyRects, buffer, width, height):
        print "on paint"
        if paintElementType == cefpython.PET_POPUP:
            print("width=%s, height=%s" % (width, height))
        elif paintElementType == cefpython.PET_VIEW:
            global state
            if state == 'image loaded':
                image = Image.frombuffer("RGBA", (width, height), buffer.GetString(mode="rgba", origin="top-left"), "raw", "RGBA", 0, 1)
                saveImage(image)
                state = 'image saved'

        else:
            raise Exception("Unknown paintElementType: %s" % paintElementType)

    def GetViewRect(self, browser, rect):
        global width, height
        rect.append(0)
        rect.append(0)
        rect.append(1000)
        rect.append(1000)
        print rect
        return True

    def GetScreenPoint(self, browser, viewX, viewY, screenCoordinates):
        print("GetScreenPoint()")
        return False

    def OnLoadEnd(self, browser, frame, httpStatusCode):
        print "on load end"
        print httpStatusCode
        return
    
    def OnLoadError(self, browser, frame, errorCode, errorText, failedURL):
        print("load error", browser, frame, errorCode, errorText, failedURL)

cefpython.g_debug = True

g_switches = {
    # On Mac it is required to provide path to a specific
    # locale.pak file. On Win/Linux you only specify the
    # ApplicationSettings.locales_dir_path option.
    "locale_pak": cefpython.GetModuleDirectory()
        +"/Resources/en.lproj/locale.pak",
}

cefpython.Initialize(settings, g_switches)
windowInfo = cefpython.WindowInfo()

#You can pass 0 to parentWindowHandle, but then some things like context menus and plugins may not display correctly. 
windowInfo.SetAsOffscreen(0)

# By default window rendering is 30 fps, let's change
# it to 60 for better user experience when scrolling.
# browserSettings = { "extra-browser-args": "off-screen-rendering-enabled" }
browserSettings = { "webgl_disabled": True }

# Using non about:blank in constructor results in error before render handler callback is set.
# Either set it before/during construction, or set it after then call LoadURL after it is set.
browser = cefpython.CreateBrowserSync(
                windowInfo, browserSettings,
                navigateUrl="http://localhost:8000/rasterizer")

browser.SetClientHandler(ClientHandler(browser))
browser.SendFocusEvent(True)

browser.SetClientCallback("OnLoadEnd", onLoadEnd)


bindings = cefpython.JavascriptBindings(bindToFrames=True, bindToPopups=True)

bindings.SetFunction("saveOnServer", saveOnServer)
browser.SetJavascriptBindings(bindings)

browser.WasResized()

main_loop()
cefpython.MessageLoop()



'''    IMPORTANT: there is a bug in CEF 3 that causes js bindings to be removed when LoadUrl() is called (see http://www.magpcss.org/ceforum/viewtopic.php?f=6&t=11009). A temporary fix to this bug is to do the navigation through javascript by calling: GetMainFrame().ExecuteJavascript('window.location="http://google.com/"'). '''
#browser.GetMainFrame().ExecuteJavascript('window.location="http://www.panda3d.org"')
#browser.GetMainFrame().LoadUrl("http://wwww.panda3d.org")
#base.accept("window-event", setBrowserSize)
# taskMgr.add(messageLoop, "CefMessageLoop")

# run()
# cefpython.Shutdown()

