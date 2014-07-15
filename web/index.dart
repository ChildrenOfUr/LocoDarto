library LocoDarto;

import "dart:html";
import "dart:math";
import "dart:async";
import "dart:convert";

import 'package:html5_dnd/html5_dnd.dart';
import 'package:libld/libld.dart'; // Nice and simple asset loading.

part 'loop.dart';
part 'render.dart';
part 'street.dart';
part 'player.dart';
part 'animation.dart';
part 'input.dart';
part 'ui.dart';

TextInputElement startColorInput, endColorInput, locationInput;
NumberInputElement widthInput, heightInput;
DivElement location;
String startColor, endColor, currentLayer = "middleground";
int width = 3000 , height = 1000;
DivElement gameScreen, layers;
Rectangle bounds;
Random rand = new Random();
SortableGroup sortGroup;

class Deco
{
	Map decoMap;
	Deco(this.decoMap);
}

// Declare our game_loop
double lastTime = 0.0;
DateTime startTime = new DateTime.now();

gameLoop(num delta)
{
	double dt = (delta-lastTime)/1000;
	loop(dt);
	render();
	lastTime = delta;
	//uncomment next line and comment 2 lines from here for max fps
	//Timer.run(() => gameLoop(new DateTime.now().difference(startTime).inMilliseconds.toDouble()));
	window.animationFrame.then(gameLoop);
}

main()
{
	gameScreen = querySelector("#GameScreen");
	
	layers = new DivElement()
		..id = "layers"
		..style.position = "absolute";
		
	gameScreen.append(layers);
	
	startColorInput = querySelector("#StartColor") as TextInputElement;
    endColorInput = querySelector("#EndColor") as TextInputElement;
    widthInput = querySelector("#Width") as NumberInputElement;
    heightInput = querySelector("#Height") as NumberInputElement;
	
	updateBounds(0,0,int.parse(widthInput.value),int.parse(heightInput.value));
	startColor = startColorInput.value.replaceAll("#", "");
	endColor = endColorInput.value.replaceAll("#", "");
	updateGradient();
	
	startColorInput.onInput.listen((_)
	{
		startColor = startColorInput.value.replaceAll("#", "");
		updateGradient();
	});
	endColorInput.onInput.listen((_)
	{
		endColor = endColorInput.value.replaceAll("#", "");
		updateGradient();
	});
    
    widthInput.onInput.listen((_)
	{
		width = int.parse(widthInput.value.replaceAll("px", ""));
		updateBounds(0,0,width,height);
	});
    heightInput.onInput.listen((_)
	{
		height = int.parse(heightInput.value.replaceAll("px", ""));
		updateBounds(0,0,width,height);
	});
    
    locationInput = querySelector("#LocationInput") as TextInputElement;
    location = querySelector("#Location");
    location.text = locationInput.value;
    
    locationInput.onInput.listen((_)
	{
		location.text = locationInput.value;
	});
    
    DivElement generateButton = querySelector("#Generate");
    generateButton.onMouseDown.listen((_)
	{
		generateButton.classes.remove("shadow");
	});
    generateButton.onMouseUp.listen((_)
	{
    	generate();
		generateButton.classes.add("shadow");
	});
    
    sortGroup = new SortableGroup(handle: 'span');
    sortGroup.onSortUpdate.listen((SortableEvent event)
	{
		DivElement movedLayer = layers.querySelector("#${event.draggable.id}");
		movedLayer.parent.insertBefore(movedLayer, movedLayer.parent.children[event.newPosition.index+1]);
	});
    
    DivElement addNewLayer = querySelector("#addNewLayer");
    addNewLayer.onMouseDown.listen((_)
	{
		addNewLayer.classes.remove("shadow");
	});
    addNewLayer.onMouseUp.listen((_)
	{
    	newLayer();
		addNewLayer.classes.add("shadow");
	});
    
    DivElement addNewExit = querySelector("#addNewExit");
    addNewExit.onMouseDown.listen((_)
	{
		addNewExit.classes.remove("shadow");
	});
    addNewExit.onMouseUp.listen((_)
	{
    	newExit();
		addNewExit.classes.add("shadow");
	});
    
    DivElement deleteDeco = querySelector("#DeleteDeco");
    deleteDeco.onMouseDown.listen((_)
	{
		deleteDeco.classes.remove("shadow");
	});
    deleteDeco.onMouseUp.listen((_)
	{
    	querySelector(".deco.dashedBorder").remove();
    	querySelector("#DecoDetails").hidden = true;
		deleteDeco.classes.add("shadow");
	});
    
    CheckboxInputElement flipDeco = querySelector("#FlipDeco") as CheckboxInputElement;
    flipDeco.onChange.listen((_)
	{
    	Element selectedDeco = querySelector(".deco.dashedBorder");
    	//special case for deco that is rotated
    	if(selectedDeco.style.transform.contains("rotate"))
    	{
    		if(flipDeco.checked)
    			selectedDeco.style.transform += " scale(-1,1)";
    		else if(!flipDeco.checked && selectedDeco.style.transform.contains("scale"))
    			selectedDeco.style.transform = "rotate("+(getTransformAngle(selectedDeco.getComputedStyle().transform)+180).toString()+"deg)";
    	}
    	
    	selectedDeco.classes.toggle("flip");
	});
        
    newLayer("middleground");
    
    CheckboxInputElement platformCheckbox = querySelector("#platformCheckbox") as CheckboxInputElement;
    platformCheckbox.onChange.listen((_)
	{
		if(platformCheckbox.checked)
		{
			showLineCanvas();
			platformCheckbox.blur();
		}
		else
			querySelector("#lineCanvas").remove();
	});
    
    InputElement fileLoad = querySelector("#fileLoad") as InputElement;
    fileLoad.onChange.listen((_)
	{
    	//the user hit cancel
    	if(fileLoad.files.length == 0)
    		return;
    	
		File file = fileLoad.files.first;
		FileReader reader = new FileReader();
		reader.onLoad.listen((_)
		{
			loadStreet(JSON.decode(reader.result));
		});
		reader.readAsText(file);
		fileLoad.blur();
	});
    
    querySelector('#LocationCodeForm').onSubmit.listen((Event e)
    {
    	e.preventDefault();
    	loadLocationJson();
    });
    
    querySelector("#LocationCodeButton").onClick.listen((_) => loadLocationJson());
    
    window.onMessage.listen((MessageEvent event)
	{
		loadStreet(JSON.decode(event.data));
	});
    
    CheckboxInputElement gravity = querySelector("#gravity") as CheckboxInputElement;
    gravity.onChange.listen((_)
    {
    	CurrentPlayer.doPhysicsApply = gravity.checked;
    });
    
    DivElement palette = querySelector("#Palette");
    ButtonElement loadAll = querySelector("#LoadAllDecos") as ButtonElement;
    loadDecos(querySelector("#DecoShelf"));
    loadDecos(querySelector("#SpritesheetShelf"));
    
    StreamSubscription scrollLoader = querySelectorAll(".shelf").onScroll.listen((_)
    {
    	String activeShelf = querySelector("input[name='paletteGroup']:checked").id;
    	Element shelf = querySelector("#${activeShelf}Shelf");
    	if((shelf.scrollHeight - shelf.offsetHeight - shelf.scrollTop).abs() < 50)
    	{
    		loadDecos(shelf, offset:int.parse(shelf.attributes["loadOffset"]));
    	}
    });
    
    loadAll.onClick.first.then((_)
    {
    	loadAll.disabled = true;
    	Element decoShelf = querySelector("#DecoShelf");
    	Element spritesheetShelf = querySelector("#SpritesheetShelf");
    	loadDecos(decoShelf,length:-1,offset:int.parse(decoShelf.attributes["loadOffset"]));
    	loadDecos(spritesheetShelf,length:-1,offset:int.parse(spritesheetShelf.attributes["loadOffset"]));
    	scrollLoader.cancel();
    	querySelector("#ScrollToLoad").hidden = true;
    });
    
    TextInputElement paletteFilter = querySelector("#PaletteFilter") as TextInputElement;
    paletteFilter.onInput.listen((_) => filterPalette());
    paletteFilter.onChange.listen((_) => filterPalette(doSearch:true));
    
    ui.init();
    playerInput = new Input();
    playerInput.init();
    currentStreet = new Street(generate());
    currentStreet.load().then((_)
    {
    	CurrentPlayer = new Player();
		CurrentPlayer.loadAnimations().then((_) => gameLoop(0.0));
    });
}

void loadLocationJson()
{
	String location = (querySelector("#LocationCodeInput") as TextInputElement).value;
	if(location != "")
	{
		if(location.startsWith("L"))
			location = location.replaceFirst("L", "G");
		String url = "http://RobertMcDermot.github.io/CAT422-glitch-location-viewer/locations/$location.callback.json";
		ScriptElement loadStreet = new ScriptElement();
		loadStreet.src = url;
        document.body.append(loadStreet);
	}
}

//dir is the name of the directory relative to listSprites.php from which to load images
void loadDecos(Element container, {int offset:0, int length:100, String search:"-1"})
{
	String dir = container.attributes["dir"];
    HttpRequest.getString("http://childrenofur.com/locodarto/listSprites.php?dir=$dir&search=$search&offset=$offset&length=$length").then((String result)
    {
    	List results = JSON.decode(result);
    	results.forEach((String spriteUrl)
		{
    		String title = spriteUrl.substring(spriteUrl.lastIndexOf("/")+1,spriteUrl.lastIndexOf("."));
    		if(querySelector("#$title") == null)
			{
    			ImageElement deco = new ImageElement();
        		deco.title = title;
        		deco.id = title;
        		deco.classes.add("paletteItem");
    			deco.src = spriteUrl;
            	deco.style.maxWidth = "50px";
            	deco.style.maxHeight = "100px";
            	container.append(deco);
            	setupListener(deco);
			}
		});
    	
    	filterPalette();
    });
    
    if(length >= 0)
    {
    	int loadOffset = int.parse(container.attributes["loadOffset"]);
    	loadOffset += length;
    	container.attributes["loadOffset"] = loadOffset.toString();
    }
}

void filterPalette({bool doSearch:false})
{
	DivElement palette = querySelector("#Palette");
    TextInputElement paletteFilter = querySelector("#PaletteFilter");
    	
	//search server for unloaded items that match the current filter
    if(doSearch && paletteFilter.value.trim() != "")
    {
    	String activeShelf = querySelector("input[name='paletteGroup']:checked").id;
        Element shelf = querySelector("#${activeShelf}Shelf");
    	loadDecos(shelf,search:paletteFilter.value);	
    }
	
	palette.querySelectorAll(".paletteItem").forEach((Element deco)
	{
		if(paletteFilter.value.trim() == "")
			deco.style.display = "inline";
		else if(deco.title.toLowerCase().contains(paletteFilter.value.toLowerCase()))
			deco.style.display = "inline";
		else
			deco.style.display = "none";
	});		
}

void setupListener(ImageElement deco)
{
	deco.onClick.listen((MouseEvent event)
	{
		querySelectorAll(".deco").forEach((Element e)
		{
			e.classes.remove("dashedBorder");
			querySelector("#DecoDetails").hidden = true;
		});
		StreamSubscription moveListener, clickListener;
		
		ImageElement drag = new ImageElement(src:deco.src);
		drag.style.position = "absolute";
		drag.style.top = (event.client.y-drag.naturalHeight).toString()+"px";
		drag.style.left = event.client.x.toString()+"px";
		drag.classes.add("dashedBorder");
		document.body.append(drag);
		
		Element layer = querySelector("#$currentLayer");
		clickListener = layers.onClick.listen((MouseEvent event)
    	{			
			num x,y;
			//if we clicked on another deco inside the target layer
    		if((event.target as Element).id != layer.id)
    		{
    			y = (event.target as Element).offset.top+event.layer.y+currentStreet.offsetY[currentLayer];
    			x = (event.target as Element).offset.left+event.layer.x+currentStreet.offsetX[currentLayer];
    		}
    		//else we clicked on empty space in the layer
    		else
    		{
    			y = event.layer.y+currentStreet.offsetY[currentLayer];
    			x = event.layer.x+currentStreet.offsetX[currentLayer];
    		}
    		drag.style.top = (y-drag.clientHeight).toString()+"px";
            drag.style.left = x.toString()+"px";
            drag.classes.add("deco");
            drag.classes.remove("dashedBorder");
            drag.onClick.listen((_) => editDetails(drag));
            
            layer.append(drag);
            editDetails(drag);

            moveListener.cancel();
            clickListener.cancel();
    	});
		
		moveListener = document.body.onMouseMove.listen((MouseEvent event)
    	{
    		drag.style.top = (event.page.y-drag.clientHeight).toString()+"px";
            drag.style.left = (event.page.x+1).toString()+"px";
    	});
	});
}

StreamSubscription xInputListener,yInputListener,zInputListener,wInputListener,hInputListener,rotateInputListener;

void editDetails(ImageElement clone)
{	
	//delete previous listeners so only one deco moves around
	if(xInputListener != null)
		xInputListener.cancel();
	if(yInputListener != null)
    	yInputListener.cancel();
	if(zInputListener != null)
    	zInputListener.cancel();
	if(wInputListener != null)
    	wInputListener.cancel();
	if(hInputListener != null)
    	hInputListener.cancel();
	if(rotateInputListener != null)
		rotateInputListener.cancel();
	
	querySelectorAll(".deco").forEach((Element e) 
	{
		if(e != clone)
			e.classes.remove("dashedBorder");
	});
	clone.classes.toggle("dashedBorder");
	Element decoDetails = querySelector("#DecoDetails");
	
	//if we just selected it
	if(clone.classes.contains("dashedBorder"))
	{
		decoDetails.hidden = false;
		
		InputElement xInput = (querySelector("#DecoX") as InputElement);
		xInput.value = clone.style.left.replaceAll("px", "");
		xInputListener = xInput.onInput.listen((_) => clone.style.left = xInput.value +"px");
		InputElement yInput = (querySelector("#DecoY") as InputElement);
		yInput.value = clone.style.top.replaceAll("px", "");
		yInputListener = yInput.onInput.listen((_) => clone.style.top = yInput.value +"px");
		InputElement zInput = (querySelector("#DecoZ") as InputElement);
		zInput.value = clone.style.zIndex;
		zInputListener = zInput.onInput.listen((_) => clone.style.zIndex = zInput.value);
		
		InputElement wInput = (querySelector("#DecoW") as InputElement);
        wInput.value = clone.style.maxWidth.replaceAll("px", "");
        wInput.placeholder = "default: " + clone.naturalWidth.toString();
        wInputListener = wInput.onInput.listen((_)
        {
        	if(wInput.value == "")
        		clone.style.maxWidth = clone.naturalWidth.toString() + "px";
        	else
        		clone.style.maxWidth = wInput.value +"px";
        });
        InputElement hInput = (querySelector("#DecoH") as InputElement);
        hInput.value = clone.style.maxHeight.replaceAll("px", "");
        hInput.placeholder = "default: " + clone.naturalHeight.toString();
        hInputListener = hInput.onInput.listen((_)
        {
        	if(hInput.value == "")
        		clone.style.maxHeight = clone.naturalHeight.toString() + "px";
        	else
        		clone.style.maxHeight = hInput.value +"px";
        });
        
        InputElement rotateInput = (querySelector("#DecoRotate") as InputElement);
        rotateInput.value = getTransformAngle(clone.getComputedStyle().transform).toString();
        rotateInputListener = rotateInput.onInput.listen((_) => clone.style.transform = "rotate("+rotateInput.value +"deg)");	
		
        (querySelector("#FlipDeco") as CheckboxInputElement).checked = clone.classes.contains("flip");
		//special case for rotated deco which needs to also be flipped...
        if(clone.style.transform.contains("rotate") && clone.classes.contains("flip"))
        	clone.style.transform += " scale(-1,1)";        	
	}
	//else we deselected it
	else
	{
		decoDetails.hidden = true;
	}
}

num getTransformAngle(String tr)
{
	if(tr == "none")
		return 0;
	
	List<String> values = tr.split('(')[1].split(')')[0].split(',');
    num a = num.parse(values[0]);
    num b = num.parse(values[1]);
    num angle = (atan2(b, a) * (180/PI));
    return angle;
}

void loadStreet(Map streetData)
{
	layers.children.clear();
    querySelector("#layerList").children.clear();
        	
	CurrentPlayer.doPhysicsApply = false;
	currentStreet = new Street(streetData);
	currentStreet.load().then((_)
	{
		startColorInput.value = "#"+currentStreet._data['gradient']['top'];
    	endColorInput.value = "#"+currentStreet._data['gradient']['bottom'];
    	widthInput.value = currentStreet.streetBounds.width.toString();
    	heightInput.value = currentStreet.streetBounds.height.toString();
    	locationInput.value = currentStreet.label;
    	
    	updateGradient();
    	width = currentStreet.streetBounds.width;
    	height = currentStreet.streetBounds.height;
    	updateBounds(0,0,width,height);
    	location.text = locationInput.value;
    	
    	for(Map layer in new Map.from(currentStreet._data['dynamic']['layers']).values)
		{
			newLayer(layer["name"],true);
		}
    	CurrentPlayer.doPhysicsApply = true;
	});
}

void showLineCanvas()
{	
	CanvasElement lineCanvas = new CanvasElement()
		..classes.add("streetcanvas")
		..style.position = "absolute"
		..width = bounds.width
		..height = bounds.height
		..attributes["ground_y"] = currentStreet._data['dynamic']['ground_y'].toString()
		..id = "lineCanvas";
	layers.append(lineCanvas);
	
	camera.dirty = true; //force a recalculation of any offset
	
	repaint(lineCanvas);
	
	int startX = -1, startY = -1;

	lineCanvas.onMouseDown.listen((MouseEvent event)
	{
		startX = event.layer.x+currentStreet.offsetX["lineCanvas"].toInt();
		startY = event.layer.y+currentStreet.offsetY["lineCanvas"].toInt();
	});
	lineCanvas.onMouseMove.listen((MouseEvent event)
	{
		if(startX == -1)
			return;
		
		Point start = new Point(startX,startY);
		Point end = new Point(event.layer.x+currentStreet.offsetX["lineCanvas"].toInt(),event.layer.y+currentStreet.offsetY["lineCanvas"].toInt());
		Platform temporary = new Platform("temp",start,end);
		repaint(lineCanvas,temporary);
	});
	lineCanvas.onMouseUp.listen((MouseEvent event)
	{
		if(startX == -1)
			return;
		
		int endX = event.layer.x+currentStreet.offsetX["lineCanvas"].toInt();
		int endY = event.layer.y+currentStreet.offsetY["lineCanvas"].toInt();
		//make sure the startX is < endX
		if(endX < startX)
		{
			int tempX = endX;
			int tempY = endY;
			endX = startX;
			startX = tempX;
			endY = startY;
			startY = tempY;
		}
		Point start = new Point(startX,startY);
		Point end = new Point(endX,endY);
		Platform newPlat = new Platform("plat_"+rand.nextInt(10000000).toString(),start,end);
		currentStreet.platforms.add(newPlat);
		currentStreet.platforms.sort((x,y) => x.compareTo(y));
		repaint(lineCanvas);
		
		startX = -1;
	});
}

void repaint(CanvasElement lineCanvas, [Platform temporary])
{
	CanvasRenderingContext2D context = lineCanvas.context2D;
	context.clearRect(0, 0, lineCanvas.width, lineCanvas.height);
	context.beginPath();
	for(Platform platform in currentStreet.platforms)
	{
		context.moveTo(platform.start.x, platform.start.y);
		context.lineTo(platform.end.x, platform.end.y);
	}
	if(temporary != null)
	{
		context.moveTo(temporary.start.x, temporary.start.y);
        context.lineTo(temporary.end.x, temporary.end.y);
	}
	context.stroke();
}

void newExit([String exitName])
{
	Element exitList = querySelector("#exitList");
	
	LIElement item = new LIElement();
	ImageElement deleteButton = new ImageElement(src:"assets/images/delete.png")
		..classes.add("deleteButton");
	TextInputElement titleInput = new TextInputElement()
		..classes.add("exitTitle")
		..placeholder = "street name";
	TextInputElement tsidInput = new TextInputElement()
		..classes.add("exitTsid")
		..placeholder = "tsid";
	
	deleteButton.onClick.first.then((_) => item.remove());
	
	item.append(deleteButton);
	item.append(titleInput);
	item.append(tsidInput);
	exitList.append(item);
}

void newLayer([String layerName, bool loadStreet = false])
{
	Element layerList = querySelector("#layerList");
	
	LIElement item = new LIElement()..style.background = "gray";
	item.onClick.listen((_) => setCurrentLayer(item));
	
	SpanElement handle = new SpanElement()..text = "::";
	
	DivElement layerTitle = new DivElement()..id = "title"..classes.add("layerTitle");
	if(layerName == null)
		layerName = "newLayer"+rand.nextInt(1000).toString();
	
	layerTitle.text = layerName;
    item.id = layerName;
    	
	DivElement checkboxWrapper = new DivElement()..classes.add("checkbox_wrapper");
	CheckboxInputElement visible = new CheckboxInputElement()..classes.add("eye")..checked = true;
	visible.onChange.listen((_)
	{
		layers.querySelector("#$layerName").hidden = !visible.checked;
	});
	
	DivElement layerWidth = new DivElement()..id = "width"..classes.add("layerTitle")..text = bounds.width.toString()+"px";
	DivElement layerHeight = new DivElement()..id = "height"..classes.add("layerTitle")..text = bounds.height.toString()+"px";
	
	TextInputElement setTitle = new TextInputElement()..classes.add("layerTitle")..style.display = "none";
	TextInputElement setWidth = new TextInputElement()..classes.add("layerTitle")..style.display = "none";
	TextInputElement setHeight = new TextInputElement()..classes.add("layerTitle")..style.display = "none";

	layerTitle.onDoubleClick.listen((_) => edit(layerTitle,setTitle,layerTitle.text));
	layerWidth.onDoubleClick.listen((_) => edit(layerWidth,setWidth,layerTitle.text));
	layerHeight.onDoubleClick.listen((_) => edit(layerHeight,setHeight,layerTitle.text));
	
	checkboxWrapper.append(visible);
	checkboxWrapper.append(new LabelElement());
	item.append(handle);
	item.append(checkboxWrapper);
	item.append(setTitle);
	item.append(layerTitle);
	item.append(setWidth);
	item.append(layerWidth);
	item.append(setHeight);
	item.append(layerHeight);
	layerList.append(item);
	
	sortGroup.install(item);
	
	if(!loadStreet)
	{
		DivElement layer = new DivElement()
    		..id=layerTitle.text
    		..classes.add("streetCanvas")
    		..style.position = "absolute"
    		..style.width = bounds.width.toString()+"px"
    		..style.height = bounds.height.toString()+"px"
    		..attributes["ground_y"] = "0";
    	
    	layers.append(layer);
	}
	
	setCurrentLayer(item);
	camera.dirty = true; //force a recalculation of any offset
}

void setCurrentLayer(Element item)
{
	querySelector("#layerList").children.forEach((Element element)
	{
		element.style.background = "";
	});
	currentLayer = item.id;
	item.style.background = "gray";
	
	//make the current layer the "bottom" layer in the dom
	//so that it gets mouseevents first
	layers.append(layers.querySelector("#$currentLayer"));
}

void edit(DivElement displayElement, TextInputElement editElement, String id)
{
	displayElement.style.display = "none";
	editElement.style.display = "inline-block";
	editElement.value = displayElement.text;
	editElement.focus();
	
	editElement.onKeyPress.listen((KeyboardEvent event)
	{
		if(event.charCode == 13)
		{
			Element layerList = querySelector("#layerList");
            		
			//update existing div on screen
			if(displayElement.id == "width")
			{
				String newWidth = editElement.value;
				if(!newWidth.endsWith("px"))
					newWidth += "px";
				layers.querySelector("#$id").style.width = newWidth;
			}
			if(displayElement.id == "height")
			{
				String newHeight = editElement.value;
				if(!newHeight.endsWith("px"))
					newHeight += "px";
				layers.querySelector("#$id").style.height = newHeight;
			}
			if(displayElement.id == "title")
			{
				layers.querySelector("#$id").id = editElement.value;
				layerList.querySelector("#$id").id = editElement.value;
				setCurrentLayer(layerList.querySelector("#${editElement.value}"));
			}
			
			editElement.style.display = "none";
			displayElement.style.display = "inline-block";
			displayElement.text = editElement.value;
			camera.dirty = true;
		}
	});
}

Map generate()
{
	Map streetMap = {};
	Map dynamicMap = {};
	streetMap["tsid"] = "sample_tsid_"+rand.nextInt(10000000).toString();
	streetMap["label"] = (querySelector("#LocationInput") as TextInputElement).value;
	streetMap["gradient"] = {"top":startColor,"bottom":endColor};
	streetMap["dynamic"] = dynamicMap;
	
	dynamicMap["l"] = -.5*bounds.width~/1;
	dynamicMap["r"] = .5*bounds.width~/1;
	dynamicMap["t"] = -bounds.height;
	dynamicMap["b"] = 0;
	dynamicMap["rookable_type"] = 0;
	dynamicMap["ground_y"] = 0;
	
	int count = 0;
	Map layerMap = {};
	querySelectorAll("#layerList li").forEach((Element child)
	{
		Map layer = {};
		layer["name"] = child.querySelector("#title").text;		
		layer["w"] = int.parse(child.querySelector("#width").text.replaceAll("px", ""));
		layer["h"] = int.parse(child.querySelector("#height").text.replaceAll("px", ""));
		layer["z"] = count;
		count--;
		layer["filters"] = {};
		
		List<Map> decosList = [];
		layers.querySelector("#${layer["name"]}").children.forEach((ImageElement deco)
		{
			String filename = deco.src.substring(deco.src.lastIndexOf("/")+1,deco.src.lastIndexOf("."));
            num decoX = int.parse(deco.style.left.replaceAll("px", ""))+deco.clientWidth~/2;
            num decoY = int.parse(deco.style.top.replaceAll("px", ""))+deco.clientHeight;
            if(layer["name"] == "middleground")
            {
            	decoX -= bounds.width~/2;
            	decoY -= bounds.height;
            }
			Map decoMap = {"filename":filename,"w":deco.clientWidth,"h":deco.clientHeight,"z":0,"x":decoX.toInt(),"y":decoY.toInt()};
			int rotation = getTransformAngle(deco.getComputedStyle().transform).toInt();
			if(rotation != 0)
				decoMap["r"] = rotation;
			if(deco.classes.contains("flip"))
				decoMap["h_flip"] = true;
			decosList.add(decoMap);
		});
		layer["decos"] = decosList;
		
		List<Map> signposts = [];
		querySelector("#exitList").children.forEach((Element element)
		{
			TextInputElement exitTitle = element.querySelector(".exitTitle");
			TextInputElement exitTsid = element.querySelector(".exitTsid");
        	signposts.add({"connects":[{"label":exitTitle.value,"tsid":exitTsid.value}]});
		});
		layer["signposts"] = signposts;
		
		List platforms = [];
		if(currentStreet != null)
		{
			for(Platform platform in currentStreet.platforms)
    		{
    			Map platformMap = {};
    			platformMap["id"] = platform.id;
        		platformMap["platform_item_perm"] = -1;
        		platformMap["platform_pc_perm"] = -1;
        		List<Map> endpoints = [];
    			Map start = {"name":"start","x":platform.start.x+bounds.width~/2-bounds.width,"y":platform.start.y-bounds.height};
    			Map end = {"name":"end","x":platform.end.x+bounds.width~/2-bounds.width,"y":platform.end.y-bounds.height};
    			endpoints.add(start);
    			endpoints.add(end);
    			platformMap["endpoints"] = endpoints;
    			platforms.add(platformMap);
    		}
			layer["platformLines"] = platforms;
		}
		else if(currentStreet == null)
		{
			Map defaultPlatform = {};
    		defaultPlatform["id"] = "plat_default";
    		defaultPlatform["platform_item_perm"] = -1;
    		defaultPlatform["platform_pc_perm"] = -1;
    		defaultPlatform["endpoints"] = [{"name":"start","x":-bounds.width~/2,"y":0},{"name":"end","x":bounds.width-bounds.width~/2,"y":0}];
    		layer["platformLines"] = [defaultPlatform];	
		}
		layer["ladders"] = [];
		layer["walls"] = [];
		layerMap[layer["name"]] = layer;
	});
	
	dynamicMap["layers"] = layerMap;
	
	if(currentStreet != null)
	{
		//download file
		var pom = document.createElement('a');
        pom.setAttribute('href', 'data:application/json;charset=utf-8,' + Uri.encodeComponent(JSON.encode(streetMap)));
        pom.setAttribute('download', streetMap["label"]+".street");
        pom.click();	
	}
        
	return streetMap;
}

void updateBounds(num left, num top, num width, num height)
{
	bounds = new Rectangle(left,top,width,height);
	updateGradient();
}

void updateGradient()
{
	Element gradientLayer = layers.querySelector("#gradient");
	if(gradientLayer == null)
		return;
	
	gradientLayer.style.width = bounds.width.toString() + "px";
	gradientLayer.style.height = bounds.height.toString() + "px";
	
	// Color the gradientCanvas
	gradientLayer.style.background = "-webkit-linear-gradient(top, #$startColor, #$endColor)";
	gradientLayer.style.background = "-moz-linear-gradient(top, #$startColor, #$endColor)";
	gradientLayer.style.background = "-ms-linear-gradient(#$startColor, #$endColor)";
	gradientLayer.style.background = "-o-linear-gradient(#$startColor, #$endColor)";
}