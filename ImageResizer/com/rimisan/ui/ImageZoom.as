import mx.utils.Delegate;
import mx.transitions.Tween;
import flash.geom.Point;
import flash.geom.Rectangle;
import com.rimisan.ui.MovieClipEx;
[IconFile("ImageZoom.png")]
class com.rimisan.ui.ImageZoom extends MovieClip{
		public  var content_mc:MovieClipEx;
		private var mask_mc:MovieClip;
		private var mcL:MovieClipLoader;
		private var __height:Number;
		private var __width:Number;
		private var xInfo:XML;
		public var tw:Tween;
		public var _path:String;
		private var crop_mc:MovieClip;
		private var mask2_mc:MovieClip;
		private var pAux:Point;
		private var _masked:Boolean = true;
		private var dispatchEvent:Function;
		private var originalWidth:Number, originalHeight:Number;
		private var _isLoading:Boolean = false;
		public var addEventListener:Function;
		public var removeEventListener:Function;

		private var _image:String;
		private var boudingBox_txt:TextField;
		[Inspectable(defaultValue="http://localhost/ImageZoom/Images/1.jpg")]
		public function set Image(str:String):String{
			_image = str;
			if(content_mc){
				//mask_mc.unloadMovie();
				//mask2_mc.unloadMovie();
				crop_mc.unloadMovie();
				init(false);
				createChildren();
			    arrange();
				updateAfterEvent();
			}
		}
		public function get Image():String{
			return _image;
		}
		private var _ZoomPercent:Number;
		
		[Inspectable(defaultValue=.5,type=Number)]
		public var EasingDuration:Number;
		
		[Inspectable(defaultValue="(+) Zoom")]
		public var ContextMenuZoomMoreText:String;
		
		[Inspectable(defaultValue="(-)  Zoom")]
		public var ContextMenuZoomLessText:String;
		
		[Inspectable(defaultValue="Original")]
		public var ContextMenuZoomResetText:String;
		
		[Inspectable(defaultValue=true,type=Boolean)]
		public var UseContextMenuStatus:Boolean;
		
		[Inspectable(defaultValue="Zoom Status:")]
		public var ContextMenuZoomStatusText:String;
		
		public function get IsLoading():Boolean{
			return _isLoading;
		}
		
		function ImageZoom(){
			init(true);
			createChildren();
		    arrange();
			this.menu = new ContextMenu();
			this.menu.hideBuiltInItems();
			this.menu.customItems.push(new ContextMenuItem(ContextMenuZoomMoreText,Delegate.create(this,MenuZoomMore)));
			this.menu.customItems.push(new ContextMenuItem(ContextMenuZoomLessText,Delegate.create(this,MenuZoomLess)));
			this.menu.customItems.push(new ContextMenuItem("Zoom Reset",Delegate.create(this,MenuZoomReset)));
			if(UseContextMenuStatus){
				this.menu.customItems.push(new ContextMenuItem(ContextMenuZoomStatusText,Delegate.create(this,MenuZoomReset)));
			}
			tw = new Tween();
		}
		public function ZoomMore(){
			ZoomOn(__width/2,__height/2,Math.abs(ZoomPercent));
		}
		public function ZoomLess(){
			if(content_mc._width >__width){
				ZoomOn(__width/2,__height/2,-Math.abs(ZoomPercent));
			}
		}
		public function ZoomReset(){
			crop_mc._visible = false;
			setContextMenuState(false);
			new Tween(content_mc, "_x", mx.transitions.easing.None.easeNone, content_mc._x, 0, EasingDuration, true);
			new Tween(content_mc, "_y", mx.transitions.easing.None.easeNone, content_mc._y, 0, EasingDuration, true);
			new Tween(content_mc, "_xscale", mx.transitions.easing.None.easeNone, content_mc._xscale, 100, EasingDuration, true);
			var tw:Tween = new Tween(content_mc, "_yscale", mx.transitions.easing.None.easeNone, content_mc._yscale, 100, EasingDuration, true);
			tw.onMotionFinished = Delegate.create(this,function(){setContextMenuState(true);});
		}
		public function MenuZoomMore(obj:Object, menuItem:Object):Void{
			ZoomOn(content_mc._xmouse,content_mc._ymouse,Math.abs(ZoomPercent));
		}
		public function MenuZoomLess(obj:Object, menuItem:Object):Void{
			ZoomOn(content_mc._xmouse,content_mc._ymouse,-Math.abs(ZoomPercent));
		}
		private function setContextMenuState(bool:Boolean){
			this.menu.customItems[0].enabled = bool;
			if(content_mc._xscale == 100){
				this.menu.customItems[1].enabled = false;
				this.menu.customItems[2].enabled = false;
			}else{
				this.menu.customItems[1].enabled = bool;
				this.menu.customItems[2].enabled = bool;
			}
			if(UseContextMenuStatus){
				this.menu.customItems[3].caption = ContextMenuZoomStatusText + " " + content_mc._xscale +"%";
			}
		}
		public function MenuZoomReset(obj:Object, menuItem:Object):Void{
			ZoomReset();
		}
		public function init(firstTime:Boolean):Void {
			mcL = new MovieClipLoader()
			mcL.addListener(this);
			mx.events.EventDispatcher.initialize(this);
			xInfo = new XML();
			xInfo.onLoad = Delegate.create(this,InfoLoaded);
			xInfo.ignoreWhite = true;
			pAux = new Point(0,0);
			if(firstTime){
				__width = int(_width);
				__height = int(_height);
			}
			_xscale = 100;
			_yscale = 100;
		}
		[Inspectable(defaultValue=50,type=Number)]
		public function get ZoomPercent():Number{
			if(content_mc._xscale+_ZoomPercent < 100){
				return content_mc._xscale - 100;
			}
			return _ZoomPercent;
		}
		public function set ZoomPercent(p:Number):Void{
			_ZoomPercent = p;
		}
		private function InfoLoaded(success:Boolean){
			if(success){
				var h:Number;
				var w:Number;
				var _w = Number(xInfo.firstChild.firstChild.attributes.width);
				var _h = Number(xInfo.firstChild.firstChild.attributes.height);
				if(_w>_h){
					h = int(__width * _h/_w);
					w = __width;
				}else{
					h = __height;
					w = int(__height * _w/_h);
				}
				mask_mc._width = w;
				mask_mc._height = h;
				mask2_mc._width = w;
				mask2_mc._height = h;
				originalWidth = w;
				originalHeight = h;
				mcL.loadClip(getUrlForSize(w,h),content_mc.empClip);
			}
			
		}
		private function getUrlForSize(w:Number,h:Number):String{
			_path = getPath(_image)+"Resizer.aspx?Action=Resize&ImageFileStr="+getFile(_image)+"&w="+int(w)+"&h="+int(h) ;
			return _path;
		}
		private function draw():Void{
			lineStyle(2,0xff0000);
			lineTo(_width,0);
			lineTo(_width,_height);
			lineTo(0,_height);
			lineTo(0,0);
		}
		private function createChildren():Void{
			this.attachMovie("MovieClipEx","content_mc",1);
			_isLoading = true;
			LoadInfo();
			this.attachMovie("Mask","mask_mc",2);
			this.mask_mc.duplicateMovieClip("mask2_mc",3);
			mask_mc._visible = mask2_mc._visible = boudingBox_txt._visible = false;
		}
		private function LoadInfo():Void{
			xInfo.load(getPath(_image)+"ImageInfo.aspx?ImageFileStr="+getFile(_image));
		}
		private function setSize(nW:Number, nH:Number):Void {
			_xscale = 100;
			_yscale = 100;
			if(nW) __width = int(nW);
			if(nH) __height = int(nH);
			arrange();
		}
		private function arrange():Void {
			mask_mc._width = __width;
			mask_mc._height = __height;
			mask2_mc._width = __width;
			mask2_mc._height = __height;
			mask2_mc._visible = false;
			if(xInfo.loaded){
				InfoLoaded(true);
			}
		}


		public function set height(nHeight:Number):Void {
    		setSize(null, int(nHeight));
  		}

		public function get height():Number {
			return __height;
		}

		public function set width(nWidth:Number):Void {
    		setSize(int(nWidth), null);
  		}

		public function get width():Number {
			return __width;
		}

		private function onLoadComplete(target:MovieClipEx, httpStt:Number){
			switch(target){
				case content_mc.empClip :
					if(_masked) setMasks();
					else unsetMask();
					updateAfterEvent();
					mask_mc._alpha = 50;
					content_mc.onRelease = Delegate.create(this,ContentRelease);
					content_mc.onPress = Delegate.create(this,ContentPress);
					content_mc.onReleaseOutside = function(){
						this.stopDrag();
						_parent.CreateCropedClip();
					}
					setContextMenuState(true);
					dispatchLoadEvent();
				break;
				case crop_mc:
					if(_masked) setMasks();
					else unsetMask();
					mask2_mc._alpha = 20;
					pAux = new Point(0,0);
					mask_mc.localToGlobal(pAux);
					content_mc.globalToLocal(pAux);
					crop_mc.onEnterFrame = Delegate.create(this, 
							function(){
								var p = pAux.clone();
								content_mc.localToGlobal(p);
								this.globalToLocal(p);
								crop_mc._x = p.x;
								crop_mc._y = p.y;
							}
						);
				break;
			}
			_isLoading = false;
		}
		private function getPath(url_str:String):String{
			var pos:Number = url_str.lastIndexOf("/");
			return url_str.substring(0,pos+1);
		}
		private function getFile(url_str:String):String{
			var pos:Number = url_str.lastIndexOf("/");
			return url_str.substring(pos+1,url_str.length);
		}
		private function ContentPress():Void{
					content_mc.startX = content_mc._x;
					content_mc.startY = content_mc._y;
					content_mc.startDrag(false,mask_mc._width-content_mc._width,mask_mc._height-content_mc._height);
		}
		public function ZoomOn(pX:Number,pY:Number,percent:Number,tween:Boolean):Void{
				//trace(tw.finish);
				
				setContextMenuState(false);
				if(!tween) var tween = true;
				if(crop_mc) crop_mc._visible = false;
				if(percent==undefined) var percent = ZoomPercent;
				var p:Point = content_mc.getScaledPoint(new Point(pX,pY),ZoomPercent);
				var newScale:Number = (content_mc._xscale+percent)/100;
				var newWidth:Number = originalWidth*newScale;
				var newHeight:Number = originalHeight*newScale;
				if(newWidth<__width){
					newWidth = __width;
				}
				if(newHeight<__height){
					newHeight = __height;
				}
				new Tween(content_mc, "_width", mx.transitions.easing.None.easeNone, content_mc._width, newWidth, EasingDuration, true);
				new Tween(content_mc, "_height", mx.transitions.easing.None.easeNone, content_mc._height, newHeight, EasingDuration, true);
				p = content_mc.getPointForMoveFromPoint(p.x,p.y,mask_mc._width/2,mask_mc._height/2);
				if(p.x > mask_mc._x){
					p.x = mask_mc._x;
				}//constraint esquerda
				if(p.y > mask_mc._y){
					p.y = mask_mc._y;
				}//constraint superior
				if(p.x+newWidth < mask_mc._width ){
					p.x = -(newWidth - mask_mc._width);
				}//constraint direita
				if(p.y+newHeight < mask_mc._height ){
					p.y = -(newHeight - mask_mc._height);
				}//constraint inferior
				if(tween){
					tw = new Tween(content_mc, "_x", mx.transitions.easing.None.easeNone, content_mc._x, p.x, EasingDuration, true);
					tw = new Tween(content_mc, "_y", mx.transitions.easing.None.easeNone, content_mc._y, p.y, EasingDuration, true);
					tw.onMotionFinished = Delegate.create(this,function(){
						setContextMenuState(true);
						CreateCropedClip();
						//delete tw.onMotionFinished;
					});
				}else{
					content_mc._x = p.x;
					content_mc._y = p.y;
				}
				

		}
		public function CenterOn(pX:Number,pY:Number,cropOnEnd:Boolean,useTween:Boolean){
			crop_mc._visible = false;
			if(useTween==undefined) useTween = false;
			var p:Point = content_mc.getScaledPoint(new Point(pX,pY),ZoomPercent);
			
			p = content_mc.getPointForMoveFromPoint(p.x,p.y,mask_mc._width/2,mask_mc._height/2);
			if(p.x > mask_mc._x){
				p.x = mask_mc._x;
			}//constraint esquerda
			if(p.y > mask_mc._y){
				p.y = mask_mc._y;
			}//constraint superior
			if(p.x+content_mc._width < mask_mc._width){
				p.x = -(content_mc._width - mask_mc._width);
			}//constraint direita
			if(p.y+content_mc._height < mask_mc._height){
				p.y = -(content_mc._height - mask_mc._height);
			}//constraint inferior
			if(!useTween){
				content_mc._x = p.x;
				content_mc._y = p.y;
			}else{
				new Tween(content_mc, "_x", mx.transitions.easing.None.easeNone, content_mc._x, p.x, EasingDuration, true);
				new Tween(content_mc, "_y", mx.transitions.easing.None.easeNone, content_mc._y, p.y, EasingDuration, true);
			}
			if(cropOnEnd){
				CreateCropedClip();
			}
		}
		private function ContentRelease():Void{
			
			if(content_mc.startX == content_mc._x && content_mc.startY == content_mc._y){
				ZoomOn(content_mc._xmouse,content_mc._ymouse,ZoomPercent);
			}else{
				if(crop_mc) crop_mc._visible = false;
				CreateCropedClip();
			}
			content_mc.stopDrag();
		}
		public function CreateCropedClip(){
			if(crop_mc) crop_mc.unloadMovie();
			var b = new Point(0,0);
			mask_mc.localToGlobal(b);
			content_mc.globalToLocal(b);
			b.x = b.x+(b.x*(content_mc._xscale-100)/100);
			b.y = b.y+(b.y*(content_mc._yscale-100)/100);
			createEmptyMovieClip("crop_mc",4);
			_isLoading = true;
			mcL.loadClip(getUrlToCrop(content_mc._width,content_mc._height,mask_mc._width,mask_mc._height,b.x,b.y),crop_mc);
		}
		private function getUrlToCrop(actualWidth:Number,actualHeight:Number,cropWidth:Number,cropHeight:Number,cropX:Number,cropY:Number):String{
			return getPath(_image)+"Resizer.aspx?Action=Crop&ImageFileStr="+getFile(_image)+"&w="+int(actualWidth)+"&h="+int(actualHeight)+"&wP="+int(cropWidth)+"&hP="+int(cropHeight)+"&x="+int(cropX)+"&y="+int(cropY)
		}
		private function Debug(srt:Object):Void{
			_parent.debug_txt.text+='\n'+srt.toString();
		}
		public function toggleZoomMode(){
			_ZoomPercent = (-_ZoomPercent);
		}
		public function unsetMask():Void{
			content_mc.setMask(null);
			crop_mc.setMask(null);
			_masked = false;
		}
		public function setMasks():Void{
			content_mc.setMask(mask_mc);
			crop_mc.setMask(mask2_mc);
			_masked = true;
		}
		private function dispatchLoadEvent():Void {
			  dispatchEvent({type: "LoadFinish", target: this});
		}
		public function getReferenceBounds():Object{
			var p:Point = new Point(0,0);
			var retorno = new Object();
			localToGlobal(p);
			content_mc.globalToLocal(p);
			retorno.ponto = p;
			retorno.scale = (mask_mc._width/content_mc._width)*100;
			return retorno;
		}
	}