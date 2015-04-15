this.areaToImageDataUrlWithAreasNotRasterized = function(rectangle) {
  var area, areasNotRasterized, areasNotRasterizedBox, dataURL, intersection, item, itemObject, j, k, len, len1, len2, m, ref, ref1, ref2, selectedItems, viewCenter, viewIntersection;
  if (view.zoom !== 1) {
    g.romanesco_alert("You are creating or modifying an item in a zoom different than 100. \nThis will not be rasterized, other users will have to render it \n(please consider drawing and modifying items at zoom 100 for better loading performances).", "warning", 3000);
    return {
      dataURL: null,
      rectangle: rectangle,
      areasNotRasterized: [g.boxFromRectangle(rectangle)]
    };
  }
  viewCenter = view.center;
  view.center = view.bounds.topLeft.round().add(view.size.multiply(0.5));
  rectangle = g.expandRectangleToInteger(rectangle);
  intersection = rectangle.intersect(view.bounds);
  intersection = g.shrinkRectangleToInteger(intersection);
  viewIntersection = g.roundRectangle(g.projectToViewRectangle(intersection));
  if (view.bounds.contains(rectangle) && !g.shrinkRectangleToInteger(intersection).equals(rectangle)) {
    console.log("ERROR: good error :-) but unlikely...");
    debugger;
  }
  if (!rectangle.topLeft.round().equals(rectangle.topLeft) || !rectangle.bottomRight.round().equals(rectangle.bottomRight)) {
    console.log('Error: rectangle is not rounded!');
    debugger;
  }
  if (!intersection.topLeft.round().equals(intersection.topLeft) || !intersection.bottomRight.round().equals(intersection.bottomRight)) {
    console.log('Error: rectangle is not rounded!');
    debugger;
  }
  if (!viewIntersection.topLeft.round().equals(viewIntersection.topLeft) || !viewIntersection.bottomRight.round().equals(viewIntersection.bottomRight)) {
    console.log('Error: rectangle is not rounded!');
    debugger;
  }
  selectedItems = [];
  ref = project.getItems({
    selected: true
  });
  for (j = 0, len = ref.length; j < len; j++) {
    item = ref[j];
    if (((ref1 = item.constructor) != null ? ref1.name : void 0) !== "Group" && ((ref2 = item.constructor) != null ? ref2.name : void 0) !== "Layer") {
      selectedItems.push({
        item: item,
        fullySelected: item.fullySelected
      });
    }
  }
  project.activeLayer.selected = false;
  g.carLayer.visible = false;
  g.debugLayer.visible = false;
  view.update();
  dataURL = areaToImageDataUrl(viewIntersection, false);
  view.center = viewCenter;
  g.debugLayer.visible = true;
  g.carLayer.visible = true;
  for (k = 0, len1 = selectedItems.length; k < len1; k++) {
    itemObject = selectedItems[k];
    if (itemObject.fullySelected) {
      itemObject.item.fullySelected = true;
    } else {
      itemObject.item.selected = true;
    }
  }
  areasNotRasterized = g.getRectangleListFromIntersection(rectangle, intersection);
  areasNotRasterizedBox = (function() {
    var len2, m, results1;
    results1 = [];
    for (m = 0, len2 = areasNotRasterized.length; m < len2; m++) {
      area = areasNotRasterized[m];
      results1.push(g.boxFromRectangle(area));
    }
    return results1;
  })();
  for (m = 0, len2 = areasNotRasterized.length; m < len2; m++) {
    area = areasNotRasterized[m];
    console.log(area);
  }
  return {
    dataURL: dataURL,
    rectangle: intersection,
    areasNotRasterized: areasNotRasterizedBox
  };
};

this.addAreasToUpdate = function(newAreasToUpdate) {
  var area, debugRectangle, j, len, rectangle;
  for (j = 0, len = newAreasToUpdate.length; j < len; j++) {
    area = newAreasToUpdate[j];
    if (g.areasToUpdate[area._id.$oid] != null) {
      continue;
    }
    rectangle = g.rectangleFromBox(area);
    g.areasToUpdate[area._id.$oid] = rectangle;
    debugRectangle = new Path.Rectangle(rectangle);
    debugRectangle.strokeColor = 'red';
    debugRectangle.strokeWidth = 1;
    debugRectangle.name = area._id.$oid;
    g.debugLayer.addChild(debugRectangle);
    g.areasToUpdateRectangles[area._id.$oid] = debugRectangle;
  }
};

this.updateRasters = function(rectangle, areaPk) {
  var area, br, extraction, j, len, planet, ref, ref1, tl;
  if (areaPk == null) {
    areaPk = null;
  }
  extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle);
  console.log('request to add ' + ((ref = extraction.areasNotRasterized) != null ? ref.length : void 0) + ' areas');
  ref1 = extraction.areasNotRasterized;
  for (j = 0, len = ref1.length; j < len; j++) {
    area = ref1[j];
    console.log("---");
    console.log(area);
    planet = new Point(area.planet);
    tl = posOnPlanetToProject(area.tl, planet);
    br = posOnPlanetToProject(area.br, planet);
    console.log(new Rectangle(tl, br).toJSON());
  }
  if (extraction.dataURL === "data:,") {
    console.log("Warning: trying to add an area outside the screen!");
  }
};

this.batchUpdateRastersCallback = function(results) {
  var j, len, result;
  for (j = 0, len = results.length; j < len; j++) {
    result = results[j];
    updateRastersCallback(result);
  }
};

this.updateRastersCallback = function(results) {
  var area, areaToDeletePk, debugRectangle, j, k, len, len1, newAreasToUpdate, ref, ref1;
  if (!g.checkError(results)) {
    return;
  }
  if (results.state === 'log' && results.message === 'Delete impossible: area does not exist') {
    return;
  }
  if (results.areasDeleted != null) {
    ref = results.areasDeleted;
    for (j = 0, len = ref.length; j < len; j++) {
      areaToDeletePk = ref[j];
      if (g.areasToUpdate[areaToDeletePk] != null) {
        debugRectangle = debugLayer.getItem({
          name: areaToDeletePk
        });
        if (debugRectangle != null) {
          debugRectangle.strokeColor = 'green';
          setTimeout((function(debugRectangle) {
            return function() {
              return debugRectangle.remove();
            };
          })(debugRectangle), 2000);
        }
        delete g.areasToUpdate[areaToDeletePk];
      } else {
        console.log('Error: area to delete could not be found');
        debugger;
      }
    }
  }
  newAreasToUpdate = [];
  if (results.areasToUpdate != null) {
    ref1 = results.areasToUpdate;
    for (k = 0, len1 = ref1.length; k < len1; k++) {
      area = ref1[k];
      newAreasToUpdate.push(JSON.parse(area));
    }
  }
  g.addAreasToUpdate(newAreasToUpdate);
};

this.updateAreasToUpdate = function() {
  var areaNotRasterized, areaToDeletePks, arg, args, debugRectangle, extraction, intersection, j, k, len, len1, len2, m, pk, rectangle, ref, ref1, ref2, viewUpdated;
  if (view.zoom !== 1) {
    return;
  }
  viewUpdated = false;
  args = [];
  ref = g.areasToUpdate;
  for (pk in ref) {
    rectangle = ref[pk];
    intersection = rectangle.intersect(view.bounds);
    if ((rectangle.width > 1 && intersection.width <= 1) || (rectangle.height > 1 && intersection.height <= 1)) {
      continue;
    }
    debugRectangle = g.areasToUpdateRectangles[pk];
    if (debugRectangle != null) {
      debugRectangle.strokeColor = 'blue';
      setTimeout((function(debugRectangle) {
        return function() {
          return debugRectangle.remove();
        };
      })(debugRectangle), 2000);
    } else {
      console.log('Error: could not find debug rectangles');
    }
    if (!viewUpdated) {
      viewUpdated = true;
    }
    extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle);
    if (extraction.dataURL === "data:,") {
      console.log("Warning: trying to add an area outside the screen!");
    }
    args.push({
      'data': extraction.dataURL,
      'position': extraction.rectangle.topLeft,
      'areasNotRasterized': extraction.areasNotRasterized,
      'areaToDeletePk': pk
    });
    delete g.areasToUpdate[pk];
  }
  areaToDeletePks = [];
  for (j = 0, len = args.length; j < len; j++) {
    arg = args[j];
    if (areaToDeletePks.indexOf(arg.areaToDeletePk) >= 0) {
      console.log('areaToDeletePk is twice!!');
      debugger;
    }
    ref1 = arg.areasNotRasterized;
    for (k = 0, len1 = ref1.length; k < len1; k++) {
      areaNotRasterized = ref1[k];
      ref2 = g.areasToUpdate;
      for (rectangle = m = 0, len2 = ref2.length; m < len2; rectangle = ++m) {
        pk = ref2[rectangle];
        intersection = areaNotRasterized.intersect(rectangle);
        if (intersection.area > 0) {
          console.log('rectangles ' + rectangle.toString() + ', and ' + areaNotRasterized.toString() + ' should not intersect');
          debugger;
        }
      }
    }
    areaToDeletePks.push(arg.areaToDeletePk);
  }
  if (args.length > 0) {
    Dajaxice.draw.batchUpdateRasters(g.batchUpdateRastersCallback, {
      'args': args
    });
  }
  g.willUpdateAreasToUpdate = false;
};

this.updateView = function(ritem) {
  var item, pk, raster, rasterColumn, ref, ref1, x, y;
  if (ritem == null) {
    ritem = null;
  }
  ref = g.rasters;
  for (x in ref) {
    rasterColumn = ref[x];
    for (y in rasterColumn) {
      raster = rasterColumn[y];
      raster.remove();
      delete g.rasters[x][y];
      if (g.isEmpty(g.rasters[x])) {
        delete g.rasters[x];
      }
    }
  }
  ref1 = g.paths;
  for (pk in ref1) {
    item = ref1[pk];
    item.draw();
  }
};

this.rasterizeArea = function(rectangle) {
  var b, dataURL, height, item, j, k, l, len, m, r, ref, ref1, ref2, ref3, ref4, ref5, ref6, restoreView, selectedItems, t, viewCenter, viewZoom, width, x, y;
  rectangle = g.expandRectangleToInteger(rectangle);
  viewCenter = view.center;
  viewZoom = view.zoom;
  selectedItems = [];
  ref = project.getItems({
    selected: true
  });
  for (j = 0, len = ref.length; j < len; j++) {
    item = ref[j];
    if (((ref1 = item.constructor) != null ? ref1.name : void 0) !== "Group" && ((ref2 = item.constructor) != null ? ref2.name : void 0) !== "Layer") {
      selectedItems.push({
        item: item,
        fullySelected: item.fullySelected
      });
    }
  }
  project.activeLayer.selected = false;
  view.zoom = 1;
  view.center = view.bounds.topLeft.round().add(view.size.multiply(0.5));
  restoreView = function() {
    var itemObject, k, len1;
    view.zoom = viewZoom;
    view.center = viewCenter;
    g.debugLayer.visible = true;
    g.carLayer.visible = true;
    for (k = 0, len1 = selectedItems.length; k < len1; k++) {
      itemObject = selectedItems[k];
      if (itemObject.fullySelected) {
        itemObject.item.fullySelected = true;
      } else {
        itemObject.item.selected = true;
      }
    }
    view.update();
  };
  if (view.bounds.contains(rectangle)) {
    dataURL = areaToImageDataUrl(g.roundRectangle(g.projectToViewRectangle(rectangle)), false);
    g.rastersToUpload.push({
      data: dataURL,
      position: rectangle.topLeft
    });
  } else {
    if (rectangle.area > 4 * Math.min(view.bounds.area, 1000 * 1000)) {
      restoreView();
      return;
    }
    t = Math.floor(rectangle.top / scale);
    l = Math.floor(rectangle.left / scale);
    b = Math.floor(rectangle.bottom / scale);
    r = Math.floor(rectangle.right / scale);
    for (x = k = ref3 = l, ref4 = r; ref3 <= ref4 ? k <= ref4 : k >= ref4; x = ref3 <= ref4 ? ++k : --k) {
      for (y = m = ref5 = t, ref6 = b; ref5 <= ref6 ? m <= ref6 : m >= ref6; y = ref5 <= ref6 ? ++m : --m) {
        if (!g.areaIsQuickLoaded({
          x: x,
          y: y
        })) {
          restoreView();
          return;
        }
      }
    }
    view.center = rectangle.topLeft.add(view.size.multiply(0.5));
    while (view.bounds.bottom < rectangle.bottom) {
      while (view.bounds.right < rectangle.right) {
        width = Math.min(Math.min(view.size.width, 1000), rectangle.right - view.bounds.left);
        height = Math.min(Math.min(view.size.height, 1000), rectangle.bottom - view.bounds.top);
        dataURL = areaToImageDataUrl(new Rectangle(0, 0, width, height), false);
        g.rastersToUpload.push({
          data: dataURL,
          position: view.bounds.topLeft
        });
        view.center = view.center.add(Math.min(view.size.width, 1000), 0);
      }
      view.center = new Point(rectangle.left + view.size.width * 0.5, view.center.y + Math.min(view.size.height, 1000));
    }
  }
  if (!g.isUpdatingRasters) {
    g.loopUpdateRasters();
  }
  restoreView();
};

this.loopUpdateRasters = function(results) {
  g.checkError(results);
  if (g.rastersToUpload.length > 0) {
    g.isUpdatingRasters = true;
  } else {
    g.isUpdatingRasters = false;
  }
};

this.rasterizeAreasToUpdate = function() {
  Dajaxice.draw.getAreasToUpdate(rasterizeAreasToUpdateCallback);
};

this.rasterizeAreasToUpdateCallback = function(areas) {
  var area, rectangle;
  g.areasToRasterize = areas;
  area = g.areasToRasterize.first();
  if (!area) {
    return;
  }
  rectangle = g.rectangleFromBox(area);
  project.activeLayer.selected = false;
  g.carLayer.visible = false;
  g.debugLayer.visible = false;
  view.zoom = 1;
  view.center = rectangle.topLeft.add(view.size.multiply(0.5));
  this.rasterizeAreasToUpdate_loop();
};

this.rasterizeAreasToUpdate_loop = function() {
  var area, dataURL, height, rectangle, waitUntilLastRastersAreUpdloaded, width;
  if (g.rastersToUpload.length > 10) {
    if (!g.isUpdatingRasters) {
      g.loopUpdateRasters();
    }
    setTimeout(rasterizeAreasToUpdate_loop, 1000);
    return;
  }
  area = g.areasToRasterize.first();
  if (!area) {
    console.log('area is null, g.areasToRasterize is empty?');
    debugger;
    return;
  }
  rectangle = g.rectangleFromBox(area);
  width = Math.min(Math.min(view.size.width, 1000), rectangle.right - view.bounds.left);
  height = Math.min(Math.min(view.size.height, 1000), rectangle.bottom - view.bounds.top);
  dataURL = areaToImageDataUrl(new Rectangle(0, 0, width, height), false);
  g.rastersToUpload.push({
    data: dataURL,
    position: view.bounds.topLeft
  });
  view.update();
  view.center = view.center.add(Math.min(view.size.width, 1000), 0);
  if (view.bounds.left > rectangle.right) {
    view.center = new Point(rectangle.left + view.size.width * 0.5, view.center.y + Math.min(view.size.height, 1000));
  }
  if (view.bounds.top > rectangle.bottom) {
    g.rastersToUpload.last().areaToDeletePk = area._id.$oid;
    g.areasToRasterize.shift();
    if (g.areasToRasterize.length > 0) {
      area = g.areasToRasterize.first();
      rectangle = g.rectangleFromBox(area);
      view.center = rectangle.topLeft.add(view.size.multiply(0.5));
    } else {
      waitUntilLastRastersAreUpdloaded = function() {
        if (g.isUpdatingRasters) {
          setTimeout(waitUntilLastRastersAreUpdloaded, 1000);
        } else {
          g.loopUpdateRasters();
        }
      };
      waitUntilLastRastersAreUpdloaded();
      g.debugLayer.visible = true;
      g.carLayer.visible = true;
      return;
    }
  }
  if (!g.isUpdatingRasters) {
    g.loopUpdateRasters();
  }
  setTimeout(rasterizeAreasToUpdate_loop, 0);
};

this.getRectangleListFromIntersection = function(rectangle1, rectangle2) {
  var i, rA, rB, rC, rD, rectangle, rectangles;
  rectangles = [];
  if ((!rectangle1.intersects(rectangle2)) || (rectangle2.contains(rectangle1))) {
    return rectangles;
  }
  rA = new Rectangle();
  rA.topLeft = rectangle1.topLeft;
  rA.bottomRight = new Point(rectangle1.right, rectangle2.top);
  rectangles.push(rA);
  rB = new Rectangle();
  rB.topLeft = new Point(rectangle1.left, Math.max(rectangle2.top, rectangle1.top));
  rB.bottomRight = new Point(rectangle2.left, Math.min(rectangle2.bottom, rectangle1.bottom));
  rectangles.push(rB);
  rC = new Rectangle();
  rC.topLeft = new Point(rectangle2.right, Math.max(rectangle2.top, rectangle1.top));
  rC.bottomRight = new Point(rectangle1.right, Math.min(rectangle2.bottom, rectangle1.bottom));
  rectangles.push(rC);
  rD = new Rectangle();
  rD.topLeft = new Point(rectangle1.left, rectangle2.bottom);
  rD.bottomRight = rectangle1.bottomRight;
  rectangles.push(rD);
  i = rectangles.length - 1;
  while (i >= 0) {
    rectangle = rectangles[i];
    if (rectangle.width <= 0 || rectangle.height <= 0) {
      rectangles.splice(i, 1);
    }
    i--;
  }
  return rectangles;
};

this.testRectangleIntersection = function() {
  var j, len, p, pr, pr2, r, r2, rectangle, rectangles;
  r = new Rectangle(0, 0, 250, 400);
  pr = new Path.Rectangle(r);
  pr.strokeColor = 'blue';
  pr.strokeWidth = 5;
  r2 = new Rectangle(-30, 10, 10, 10);
  pr2 = new Path.Rectangle(r2);
  pr2.strokeColor = 'green';
  pr2.strokeWidth = 5;
  rectangles = g.getRectangleListFromIntersection(r2, r);
  for (j = 0, len = rectangles.length; j < len; j++) {
    rectangle = rectangles[j];
    p = new Path.Rectangle(rectangle);
    p.strokeColor = 'red';
    p.strokeWidth = 1;
  }
};
