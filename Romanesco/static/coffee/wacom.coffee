# *********************************************************************
# Handler called any time we want the most currently cached
# touch data packet.

touchDataEventHandler = ->
  #alert("touchDataEventHandler called!");
  updateTouchDataTables()
  return

# *********************************************************************
# Handler called when a touch device attaches.

touchDeviceAttachHandler = ->
  alert 'Detected touch device attached!'
  # Close the device that we have opened.
  closeCurrentTouchDevice()
  # Get updated list of attached devices.
  updateTouchDeviceIDList()
  # Open the first touch device in the current list of devices. 
  rebuildTouchTable 0
  return

# *********************************************************************
# Handler called when a touch device detaches.

touchDeviceDetachHandler = ->
  alert 'Detected touch device detached!'
  # Close the device that we have opened.
  closeCurrentTouchDevice()
  # Get updated list of attached devices.
  updateTouchDeviceIDList()
  # Open the first touch device in the current list of devices. 
  rebuildTouchTable 0
  return

# *********************************************************************
# Returns the touch device ID from the index_Ith device

getTouchDeviceID = (index_I) ->
  #alert("getTouchDeviceID");
  devID = -1
  if _numTouchDevices > 0 and index_I < _numTouchDevices
    devID = _touchDeviceIDList[index_I]
    #alert("getTouchDeviceID found devID: " + devID);
  else
    if _numTouchDevices > 0
      alert 'Could not get device for index: ' + index_I + '\nReturning index for first device found.'
      devID = 0
    else
      alert 'No touch devices found'
      devID = -1
  devID

# *********************************************************************

updateTouchDeviceIDList = ->
  idListIdx = 0
  idList = ''
  #alert("updateTouchDeviceIDList");
  _touchDeviceIDList = getWacomPlugin().touchAPI.TouchDeviceIDList
  _numTouchDevices = _touchDeviceIDList.length
  _docIsTouchDeviceAttached.innerHTML = '#Devices: ' + String(_numTouchDevices)
  #alert("num touch devices: " + _numTouchDevices);
  # Clear out the combo first.
  clearCombo()
  if _numTouchDevices == 0
    createEmptyCombo()
  # Now rebuild with the list of devices.
  idListIdx = 0
  while idListIdx < _numTouchDevices
    #idList = idList + String(_touchDeviceIDList[idListIdx]) + " ";
    addCombo idListIdx
    idListIdx++
  #alert("DeviceIDs: [" + idList + "]");
  return

# *********************************************************************

updateCapsFromCurrentTouchDevice = ->
  if _touchCurrentDeviceIndex < 0
    alert 'Bad _touchCurrentDeviceIndex: ' + _touchCurrentDeviceIndex
    return
  _touchCurrentDeviceID = getTouchDeviceID(_touchCurrentDeviceIndex)
  if _touchCurrentDeviceIndex >= 0
    # Get caps list based on first device.
    _touchDeviceCaps = getWacomPlugin().touchAPI.TouchDeviceCapabilities(_touchCurrentDeviceID)
  return

# *********************************************************************

openCurrentTouchDevice = ->
  # Set open Mode
  #var passthru = true;        // observe and pass touch data to system
  passthru = false
  # consume data and do not pass to system
  updateCapsFromCurrentTouchDevice()
  updateTouchCapsTable 1
  # update with current caps
  # open a connection to the current touch device
  #alert("Opening touch device ID: " + _touchCurrentDeviceID);
  theError = getWacomPlugin().touchAPI.Open(_touchCurrentDeviceID, passthru)
  if theError != 0
    alert 'unable to establish connection to wacom plugin'
  return

# *********************************************************************

closeCurrentTouchDevice = ->
  # close connection to the current touch device
  #alert("Closing touch device ID: " + _touchCurrentDeviceID);
  getWacomPlugin().touchAPI.Close _touchCurrentDeviceID
  # Clear the caps table
  updateTouchCapsTable 0
  return

# *********************************************************************
# Update the touch capabilities table.
# useCaps == 1, use current _touchDeviceCaps; else clear table.

updateTouchCapsTable = (useCaps) ->
  if _touchDeviceCaps.Version > 0
    _docMTAPIVersion.innerHTML = String(if useCaps then _touchDeviceCaps.Version else '0')
    _docDeviceID.innerHTML = String(if useCaps then _touchDeviceCaps.DeviceID else '0')
    _docDeviceType.innerHTML = String(if useCaps then _touchDeviceCaps.DeviceType else '0')
    _docMaxFingers.innerHTML = String(if useCaps then _touchDeviceCaps.MaxFingers else '0')
    _docReportedSizeX.innerHTML = String(if useCaps then _touchDeviceCaps.ReportedSizeX else '0')
    _docReportedSizeY.innerHTML = String(if useCaps then _touchDeviceCaps.ReportedSizeY else '0')
    _docPhysicalSizeX.innerHTML = String(if useCaps then Math.round(_touchDeviceCaps.PhysicalSizeX * 1000) / 1000 else '0')
    _docPhysicalSizeY.innerHTML = String(if useCaps then Math.round(_touchDeviceCaps.PhysicalSizeY * 1000) / 1000 else '0')
    _docLogicalOriginX.innerHTML = String(if useCaps then _touchDeviceCaps.LogicalOriginX else '0')
    _docLogicalOriginY.innerHTML = String(if useCaps then _touchDeviceCaps.LogicalOriginY else '0')
    _docLogicalWidth.innerHTML = String(if useCaps then _touchDeviceCaps.LogicalWidth else '0')
    _docLogicalHeight.innerHTML = String(if useCaps then _touchDeviceCaps.LogicalHeight else '0')
  return

# *********************************************************************

fingerStateDescription = (touchState) ->
  switch touchState
    when 0
      return 'None'
    when 1
      return 'Down'
    when 2
      return 'Hold'
    when 3
      return 'Up'
    else
      return 'state invalid!'
  return

# *********************************************************************

updateTouchDataTables = ->
  finger1 = undefined
  finger2 = undefined
  numFingers = undefined
  #alert("updateTouchDataTables");
  # Get touch data for as many fingers as supported.
  _touchRawFingerData = getWacomPlugin().touchAPI.TouchRawFingerData(_touchCurrentDeviceID)
  #alert("got data");
  if _touchRawFingerData.Status == -1
    #alert("Bad finger data status returned");
    return
  # Update table data
  numFingers = _touchRawFingerData.NumFingers
  _docNumFingersReported.innerHTML = _touchRawFingerData.NumFingers
  #alert("numFingers: " + _docNumFingersReported);
  # For now, only updating Finger1 and Finger2 data in the tables.
  # Add finger1 data.
  finger1 = _touchRawFingerData.FingerList[0]
  _docFingerID1.innerHTML = String(finger1.FingerID)
  _docPosX1.innerHTML = String(Math.round(finger1.PosX * 1000) / 1000)
  _docPosY1.innerHTML = String(Math.round(finger1.PosY * 1000) / 1000)
  _docWidth1.innerHTML = String(Math.round(finger1.Width * 1000) / 1000)
  _docHeight1.innerHTML = String(Math.round(finger1.Height * 1000) / 1000)
  _docOrientation1.innerHTML = String(finger1.Orientation)
  _docConfidence1.innerHTML = String(finger1.Confidence)
  _docSensitivity1.innerHTML = String(finger1.Sensitivity)
  _docFingerState1.innerHTML = fingerStateDescription(finger1.TouchState)
  #String(finger1.TouchState);
  # Add finger2 data, if any.
  if numFingers > 1
    finger2 = _touchRawFingerData.FingerList[1]
  # Note - if no finger2 data, then we post "*****" into all fields.
  _docFingerID2.innerHTML = if numFingers == 2 then String(finger2.FingerID) else '*****'
  _docPosX2.innerHTML = if numFingers == 2 then String(Math.round(finger2.PosX * 1000) / 1000) else '*****'
  _docPosY2.innerHTML = if numFingers == 2 then String(Math.round(finger2.PosY * 1000) / 1000) else '*****'
  _docWidth2.innerHTML = if numFingers == 2 then String(Math.round(finger2.Width * 1000) / 1000) else '*****'
  _docHeight2.innerHTML = if numFingers == 2 then String(Math.round(finger2.Height * 1000) / 1000) else '*****'
  _docOrientation2.innerHTML = if numFingers == 2 then String(finger2.Orientation) else '*****'
  _docConfidence2.innerHTML = if numFingers == 2 then String(finger2.Confidence) else '*****'
  _docSensitivity2.innerHTML = if numFingers == 2 then String(finger2.Sensitivity) else '*****'
  _docFingerState2.innerHTML = fingerStateDescription(finger2.TouchState)
  #String(finger2.TouchState);
  return

# *********************************************************************
# isPluginLoaded
#   Returns loaded status as plugin version string (eg: "2.0.0.2"),
#   or an empty string if plugin can't be loaded or found.
#

isPluginLoaded = ->
  retVersion = ''
  pluginVersion = getWacomPlugin().version
  #alert("pluginVersion: [" + pluginVersion + "]");
  if pluginVersion != undefined
    retVersion = pluginVersion
  retVersion

# *********************************************************************
# Any load initialization goes here.

onLoad = ->
  #alert("function onLoad");
  loadVersion = isPluginLoaded()
  if loadVersion != ''
    alert 'Loaded webplugin: ' + loadVersion
  else
    alert 'webplugin is NOT Loaded (or undiscoverable)'
    return
  # Set up binding between caps table cells and data vars.
  _docIsTouchDeviceAttached = document.getElementById('docIsTouchDeviceAttachedCell')
  _docMTAPIVersion = document.getElementById('docMTAPIVersionCell')
  _docDeviceID = document.getElementById('docDeviceIDCell')
  _docDeviceType = document.getElementById('docDeviceTypeCell')
  _docMaxFingers = document.getElementById('docMaxFingersCell')
  _docReportedSizeX = document.getElementById('docReportedSizeXCell')
  _docReportedSizeY = document.getElementById('docReportedSizeYCell')
  _docPhysicalSizeX = document.getElementById('docPhysicalSizeXCell')
  _docPhysicalSizeY = document.getElementById('docPhysicalSizeYCell')
  _docLogicalOriginX = document.getElementById('docLogicalOriginXCell')
  _docLogicalOriginY = document.getElementById('docLogicalOriginYCell')
  _docLogicalWidth = document.getElementById('docLogicalWidthCell')
  _docLogicalHeight = document.getElementById('docLogicalHeightCell')
  _docNumFingersReported = document.getElementById('docNumFingersReportedCell')
  # Set up binding between finger1 table cells and data vars.
  _docFingerID1 = document.getElementById('docFingerIDCell1')
  _docPosX1 = document.getElementById('docPosXCell1')
  _docPosY1 = document.getElementById('docPosYCell1')
  _docWidth1 = document.getElementById('docWidthCell1')
  _docHeight1 = document.getElementById('docHeightCell1')
  _docOrientation1 = document.getElementById('docOrientationCell1')
  _docConfidence1 = document.getElementById('docConfidenceCell1')
  _docSensitivity1 = document.getElementById('docSensitivityCell1')
  _docFingerState1 = document.getElementById('docFingerStateCell1')
  # Set up binding between finger2 table cells and data vars.
  _docFingerID2 = document.getElementById('docFingerIDCell2')
  _docPosX2 = document.getElementById('docPosXCell2')
  _docPosY2 = document.getElementById('docPosYCell2')
  _docWidth2 = document.getElementById('docWidthCell2')
  _docHeight2 = document.getElementById('docHeightCell2')
  _docOrientation2 = document.getElementById('docOrientationCell2')
  _docConfidence2 = document.getElementById('docConfidenceCell2')
  _docSensitivity2 = document.getElementById('docSensitivityCell2')
  _docFingerState2 = document.getElementById('docFingerStateCell2')
  # Show plugin version
  _docPluginVersion = document.getElementById('docPluginVersion')
  _docPluginVersion.innerHTML = 'Plugin Version: ' + getWacomPlugin().version
  #alert("doc vars initialized");
  BrowserDetect.init()
  #initialize identification of the browser
  # debug - init for browser that does not launch plugin in child process
  if window.opera
    getWacomPlugin().touchAPI.Modes 0
  else if BrowserDetect.browser == 'Safari' and BrowserDetect.version < 5.1
    getWacomPlugin().touchAPI.Modes 0
  else if BrowserDetect.browser == 'Firefox' and window.navigator.platform == 'MacIntel' and window.navigator.userAgent.indexOf('10.5') != -1
    #alert(window.navigator.userAgent);
    getWacomPlugin().touchAPI.Modes 0
  else
    # normal operation
    # (This call is usually not necessary.  BROWSERCHILD is the default.)
    getWacomPlugin().touchAPI.Modes 0x00000001
  registerForTouchEvents()
  updateTouchDeviceIDList()
  openCurrentTouchDevice()
  return

# *********************************************************************

addCombo = (touchDeviceIndex) ->
  combo = document.getElementById('touchDevicesCombo')
  option = document.createElement('option')
  option.text = 'Touch Device: ' + touchDeviceIndex
  option.value = touchDeviceIndex
  try
    combo.add option, null
    # standard
  catch error
    combo.add option
    #IE only
  return

# *********************************************************************

clearCombo = ->
  combo = document.getElementById('touchDevicesCombo')
  # clear the listbox first
  idx = combo.options.length - 1
  while idx >= 0
    combo.options[idx] = null
    idx--
  combo.selectedIndex = -1
  return

# *********************************************************************

createEmptyCombo = ->
  combo = document.getElementById('touchDevicesCombo')
  option = document.createElement('option')
  option.text = '(no touch devices found)'
  option.value = -1
  # Make sure the combo is empty first.
  clearCombo()
  try
    combo.add option, null
    # standard
  catch error
    combo.add option
    #IE only
  return

# *********************************************************************

rebuildTouchTable = (touchDeviceIndex) ->
  #alert("rebuildTouchTable: closing current device...");
  closeCurrentTouchDevice()
  #alert("rebuildTouchTable: rebuilding table for touch device: " + touchDeviceIndex);
  _touchCurrentDeviceIndex = touchDeviceIndex
  openCurrentTouchDevice()
  return

# ---
# generated by js2coffee 2.0.1