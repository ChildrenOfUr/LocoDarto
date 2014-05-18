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
DivElement gameScreen, gradientLayer, layers;
Rectangle bounds;
Random rand = new Random();

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
	gradientLayer = new DivElement()..id = "gradient";
	
	layers = new DivElement()
		..id = "layers"
		..style.position = "absolute";
	
	layers.append(gradientLayer);
	
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
    
    SortableGroup sortGroup = new SortableGroup(handle: 'span');
    
    DivElement addNewLayer = querySelector("#addNewLayer");
    addNewLayer.onMouseDown.listen((_)
	{
		addNewLayer.classes.remove("shadow");
	});
    addNewLayer.onMouseDown.listen((_)
	{
    	newLayer(sortGroup);
		addNewLayer.classes.add("shadow");
	});
    
    newLayer(sortGroup, "middleground");
    
    CheckboxInputElement platformCheckbox = querySelector("#platformCheckbox") as CheckboxInputElement;
    platformCheckbox.onChange.listen((_)
	{
		if(platformCheckbox.checked)
			showLineCanvas();
		else
			querySelector("#lineCanvas").remove();
	});
    
    InputElement fileLoad = querySelector("#fileLoad") as InputElement;
    fileLoad.onChange.listen((_)
	{
		File file = fileLoad.files.first;
		FileReader reader = new FileReader();
		reader.onLoad.listen((_)
		{
			loadStreet(JSON.decode(reader.result));
		});
		reader.readAsText(file);
	});
    
    CheckboxInputElement gravity = querySelector("#gravity") as CheckboxInputElement;
    gravity.onChange.listen((_)
    {
    	CurrentPlayer.doPhysicsApply = gravity.checked;
    });
    
    DivElement palette = querySelector("#Palette") as DivElement;
	ImageElement deco = new ImageElement(src:'../web/assets/sprites/decos/alakol_beach_1.png');
	deco.style.maxWidth = "50px";
	palette.append(deco);
	setupListener(deco);
    
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

void setupListener(ImageElement deco)
{
	ImageElement drag = null;
	deco.onClick.listen((MouseEvent event)
	{
		drag = new ImageElement(src:deco.src);
		drag.style.position = "absolute";
		drag.style.top = event.client.y.toString()+"px";
		drag.style.left = event.client.x.toString()+"px";
		drag.style.border = "1px dashed black";
		document.body.append(drag);
		
		Element layer = querySelector("#$currentLayer");
		print("looking for $currentLayer");
		layer.onClick.listen((MouseEvent event)
    	{
			if(drag == null)
				return;
			
    		num x,y;
    		if((event.target as Element).id != layer.id)
    		{
    			y = (event.target as Element).offset.top+event.layer.y+currentStreet.offsetY;
    			x = (event.target as Element).offset.left+event.layer.x+currentStreet.offsetX;
    		}
    		else
    		{
    			y = event.layer.y+currentStreet.offsetY;
    			x = event.layer.x+currentStreet.offsetX;
    		}
    		drag.style.top = y.toString()+"px";
            drag.style.left = x.toString()+"px";
            drag.style.border = "";
            layer.append(drag.clone(false));
            drag.remove();
            drag == null;
            event.stopImmediatePropagation();
    	});
	});
	document.body.onMouseMove.listen((MouseEvent event)
	{
		if(drag == null)
			return;
		
		drag.style.top = (event.page.y+1).toString()+"px";
        drag.style.left = event.page.x.toString()+"px";
	});
}

void loadStreet(Map streetData)
{
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
    	showLineCanvas();
    	CurrentPlayer.doPhysicsApply = true;
	});
}

void showLineCanvas()
{
	camera.dirty = true; //force a recalculation of any offset
	
	CanvasElement lineCanvas = new CanvasElement()
		..style.position = "absolute"
		..width = bounds.width
		..height = bounds.height
		..attributes["ground_y"] = currentStreet._data['dynamic']['ground_y'].toString()
		..id = "lineCanvas";
	layers.append(lineCanvas);
	
	repaint(lineCanvas);
	
	int startX = -1, startY = -1;

	lineCanvas.onMouseDown.listen((MouseEvent event)
	{
		startX = event.layer.x+currentStreet.offsetX.toInt();
		startY = event.layer.y+currentStreet.offsetY.toInt();
	});
	lineCanvas.onMouseMove.listen((MouseEvent event)
	{
		if(startX == -1)
			return;
		
		Point start = new Point(startX,startY);
		Point end = new Point(event.layer.x+currentStreet.offsetX.toInt(),event.layer.y+currentStreet.offsetY.toInt());
		Platform temporary = new Platform("temp",start,end);
		repaint(lineCanvas,temporary);
	});
	lineCanvas.onMouseUp.listen((MouseEvent event)
	{
		if(startX == -1)
			return;
		
		int endX = event.layer.x+currentStreet.offsetX.toInt();
		int endY = event.layer.y+currentStreet.offsetY.toInt();
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

void newLayer(SortableGroup sortGroup, [String layerName])
{
	Element layerList = querySelector("#layerList");
	
	LIElement item = new LIElement()..style.background = "gray";
	item.onClick.listen((_) => setCurrentLayer(item));
	
	SpanElement handle = new SpanElement()..text = "::";
	
	DivElement checkboxWrapper = new DivElement()..classes.add("checkbox_wrapper");
	CheckboxInputElement visible = new CheckboxInputElement()..classes.add("eye")..checked = true;
	LabelElement label = new LabelElement();
	
	DivElement layerTitle = new DivElement()..id = "title"..classes.add("layerTitle");
	if(layerName == null)
		layerName = "newLayer"+rand.nextInt(100000).toString();
	
	layerTitle.text = layerName;
	item.id = layerName;
	setCurrentLayer(item);
	
	DivElement layerWidth = new DivElement()..id = "width"..classes.add("layerTitle")..text = bounds.width.toString()+"px";
	DivElement layerHeight = new DivElement()..id = "height"..classes.add("layerTitle")..text = bounds.height.toString()+"px";
	
	TextInputElement setTitle = new TextInputElement()..classes.add("layerTitle")..style.display = "none";
	TextInputElement setWidth = new TextInputElement()..classes.add("layerTitle")..style.display = "none";
	TextInputElement setHeight = new TextInputElement()..classes.add("layerTitle")..style.display = "none";

	layerTitle.onDoubleClick.listen((_) => edit(layerTitle,setTitle,layerTitle.text));
	layerWidth.onDoubleClick.listen((_) => edit(layerWidth,setWidth,layerTitle.text));
	layerHeight.onDoubleClick.listen((_) => edit(layerHeight,setHeight,layerTitle.text));
	
	checkboxWrapper.append(visible);
	checkboxWrapper.append(label);
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
	
	DivElement layer = new DivElement()
		..id=layerTitle.text
		..classes.add("streetCanvas")
		..style.width = bounds.width.toString()+"px"
		..style.height = bounds.height.toString()+"px"
		..attributes["ground_y"] = "0";
	
	layers.append(layer);
}

void setCurrentLayer(Element item)
{
	querySelector("#layerList").children.forEach((Element element)
	{
		element.style.background = "";
	});
	currentLayer = item.id;
	item.style.background = "gray";
	print("currentLayer: $currentLayer");
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
				layerList.querySelector("#$id").style.width = newWidth;
			}
			if(displayElement.id == "height")
			{
				String newHeight = editElement.value;
				if(!newHeight.endsWith("px"))
					newHeight += "px";
				layerList.querySelector("#$id").style.height = newHeight;
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
		layer["decos"] = [];
		layer["signposts"] = [];
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
		else
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
}

void updateGradient()
{
	gradientLayer.style.width = bounds.width.toString() + "px";
	gradientLayer.style.height = bounds.height.toString() + "px";
	
	// Color the gradientCanvas
	gradientLayer.style.background = "-webkit-linear-gradient(top, #$startColor, #$endColor)";
	gradientLayer.style.background = "-moz-linear-gradient(top, #$startColor, #$endColor)";
	gradientLayer.style.background = "-ms-linear-gradient(#$startColor, #$endColor)";
	gradientLayer.style.background = "-o-linear-gradient(#$startColor, #$endColor)";
}