from cefpython3 import cefpython

import os
import sys

import cStringIO
import StringIO
from PIL import Image

from __future__ import absolute_import

from celery import shared_task

# from panda3d.core import loadPrcFileData
# loadPrcFileData("", "Panda3D example")
# loadPrcFileData("", "fullscreen 0")
# loadPrcFileData("", "win-size 1024 768")

# import direct.directbase.DirectStart
# from panda3d.core import CardMaker, Texture


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
    
global isLoaded
isLoaded = False

class ClientHandler:
    """A client handler is required for the browser to do built in callbacks back into the application."""
    browser = None
    mustSaveImage = False
    # texture = None

    def __init__(self, browser):
        self.browser = browser
        # self.texture = texture

    def OnPaint(self, browser, paintElementType, dirtyRects, buffer, width, height):
        # img = self.texture.modifyRamImage()
        print "on paint"
        if paintElementType == cefpython.PET_POPUP:
            print("width=%s, height=%s" % (width, height))
        elif paintElementType == cefpython.PET_VIEW:
            # img.setData(buffer.GetString(mode="rgba", origin="bottom-left"))
            # im = Image.open(StringIO.StringIO(buffer))
            # .GetString(mode="rgba", origin="top-left")
            # image = Image.open(buffer.GetString(mode="rgba", origin="top-left"))
            # image = Image.frombuffer("RGBA", (width, height), buffer.GetString(mode="rgba", origin="top-left"), "raw", "RGBA", 0, 1)
            # image.save('output.jpg')
            global isLoaded
            if isLoaded:
                image = Image.frombuffer("RGBA", (width, height), buffer.GetString(mode="rgba", origin="top-left"), "raw", "RGBA", 0, 1)
                image.save('output.jpg')
                print "image saved"

        else:
            raise Exception("Unknown paintElementType: %s" % paintElementType)

    def GetViewRect(self, browser, rect):
        # print "||||| GetViewRect |||||"
        width  = 1024 #self.texture.getXSize()
        height = 1024 #self.texture.getYSize()
        rect.append(0)
        rect.append(0)
        rect.append(width)
        rect.append(height)
        return True

    def GetScreenPoint(self, browser, viewX, viewY, screenCoordinates):
        print("GetScreenPoint()")
        return False

    def OnLoadEnd(self, browser, frame, httpStatusCode):
        print "on load end"
        print httpStatusCode
        return
        # self._saveImage()
    
    def OnLoadError(self, browser, frame, errorCode, errorText, failedURL):
        print("load error", browser, frame, errorCode, errorText, failedURL)

    # def SaveImage(self):
    #     print("save image")
    #     mustSaveImage = True
    #     return


'''def setBrowserSize(window=None):
    """Use something like this to set a full screen UI. Texture and browser size should equal window size. Also remember to set panda textures to ignore power of 2"""
      width = int(round(base.win.getXSize() * 0.75))
      height = int(round(base.win.getYSize() * 0.75))
      texture.setXSize(width)
      texture.setYSize(height)
      browser.WasResized()
      #browser.SetSize(cefpython.PET_VIEW, width, height)'''

def messageLoop(task):
    cefpython.MessageLoopWork()
    return task.cont


cefpython.g_debug = True

g_switches = {
    # On Mac it is required to provide path to a specific
    # locale.pak file. On Win/Linux you only specify the
    # ApplicationSettings.locales_dir_path option.
    "locale_pak": cefpython.GetModuleDirectory()
        +"/Resources/en.lproj/locale.pak",

    # "proxy-server": "socks5://127.0.0.1:8888",
    # "no-proxy-server": "",
    # "enable-media-stream": "",
    # "remote-debugging-port": "12345",
    # "disable-gpu": "",
    # "--invalid-switch": "" -> Invalid switch name
}

cefpython.Initialize(settings, g_switches)

def saveImage():
    print "save image"
    global isLoaded
    isLoaded = True
    return

bindings = cefpython.JavascriptBindings(bindToFrames=True, bindToPopups=True)
bindings.SetFunction("saveImage", saveImage)

# texture = Texture()
# texture.setXSize(1024)
# texture.setYSize(1024)
# texture.setCompression(Texture.CMOff)
# texture.setComponentType(Texture.TUnsignedByte)
# texture.setFormat(Texture.FRgba4)

# cardMaker = CardMaker("browser2d")
# cardMaker.setFrame(-0.75, 0.75, -0.75, 0.75)
# node = cardMaker.generate()
# #For UI attach to render2d
# nodePath = render.attachNewNode(node)
# nodePath.setTexture(texture)

# windowHandle = base.win.getWindowHandle().getIntHandle()
windowInfo = cefpython.WindowInfo()

#You can pass 0 to parentWindowHandle, but then some things like context menus and plugins may not display correctly. 
windowInfo.SetAsOffscreen(0)
#windowInfo.SetAsOffscreen(0)
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

def on_load_end(*args, **kwargs):
    # import pdb; pdb.set_trace()
    print "global on load end"
    # global isLoaded
    # isLoaded = True
    # import pdb; pdb.set_trace()
    return  # Example of one kind of call back

browser.SetClientCallback("OnLoadEnd", on_load_end)
browser.SetJavascriptBindings(bindings)

# def PyAlert(msg):
#                 win32gui.MessageBox(__browser.GetWindowID(), msg, "PyAlert()", win32con.MB_ICONQUESTION)

# bindings = cefpython.JavascriptBindings(bindToFrames=True, bindToPopups=True)
# bindings.SetFunction("alert", PyAlert)

browser.WasResized()

cefpython.MessageLoop()
'''    IMPORTANT: there is a bug in CEF 3 that causes js bindings to be removed when LoadUrl() is called (see http://www.magpcss.org/ceforum/viewtopic.php?f=6&t=11009). A temporary fix to this bug is to do the navigation through javascript by calling: GetMainFrame().ExecuteJavascript('window.location="http://google.com/"'). '''
#browser.GetMainFrame().ExecuteJavascript('window.location="http://www.panda3d.org"')
#browser.GetMainFrame().LoadUrl("http://wwww.panda3d.org")
#base.accept("window-event", setBrowserSize)
# taskMgr.add(messageLoop, "CefMessageLoop")

# run()
# cefpython.Shutdown()


@shared_task
def rasterize(x, y, width, height):
	return browser.ExecuteFunction("load_debug", x, y, width, height)

