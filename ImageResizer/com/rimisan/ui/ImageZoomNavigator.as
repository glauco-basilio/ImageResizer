import mx.utils.Delegate;
import mx.transitions.Tween;
import flash.geom.Point;
import com.rimisan.ui.MovieClipEx;
import com.rimisan.ui.ImageZoom;
import com.rimisan.ui.style.LineStyle;
[IconFile("ImageZoomNavigator.png")]
class com.rimisan.ui.ImageZoomNavigator extends MovieClipEx{
		private var _instance:ImageZoom;
		private var content_mc:MovieClipEx;
		private var navigator_mc:MovieClipEx;
		private var boudingBox_txt:TextField;
		private var mcL:MovieClipLoader;
		private var pressed:Boolean;
		private var __width:Number, __height:Number;
		private var lS:LineStyle;
		private var interval;
		private var tw:Tween;
		[Inspectable(defaultValue="#FF0000",type=Color)]
		public var GuideRectangleLineColor:String;
		
		[Inspectable(defaultValue=0,type=Number)]
		public var GuideRectangleLineWeight:Number;
		
		[Inspectable(defaultValue="#FFFFFF",type=Color)]
		public var GuideRectangleFillColor:String;
		
		[Inspectable(defaultValue=70,type=Number)]
		public var GuideRectangleFillAlpha:Number;
		
		[Inspectable(defaultValue="zoom")]
		public function set ZoomImageInstance(inst:String):Void{
			var arr:Array = inst.split(".");
			var _objAux:Object;
			_objAux = _parent[arr[0]];
			for(var i = 1;i<arr.length;i++){
				_objAux = _objAux[arr[i]];
			}
			_instance = ImageZoom(_objAux);

		}
		private function setSize(nW:Number, nH:Number):Void {
			_xscale = 100;
			_yscale = 100;
			if(nW) __width = int(nW);
			if(nH) __height = int(nH);
			drawRectangle(nW,nH,lS,Number(GuideRectangleFillColor),GuideRectangleFillAlpha)
		}
		function ImageZoomNavigator(){
			_instance.addEventListener("LoadFinish",this);
			mcL = new MovieClipLoader();
			mcL.addListener(this);
			__width = _width;
			__height = _height;
			_xscale = 100;
			_yscale = 100;
			boudingBox_txt._visible = false;
			attachMovie("MovieClipEx","navigator_mc",3);
			lS = new LineStyle();
			lS.thickness = GuideRectangleLineWeight;
			lS.rgb = Number(GuideRectangleLineColor);
			lS.noScale = LineStyle.noScaleNone;
		}
		private function LoadFinish(evtArg:Object){
			this.attachMovie("MovieClipEx","content_mc",2);
			mcL.loadClip(_instance._path,content_mc.empClip);
		}
		private function onLoadComplete(target:MovieClipEx, httpStt:Number){
				navigator_mc.onEnterFrame = Delegate.create(this,NavigatorEnterFrame);
				content_mc.onEnterFrame = Delegate.create(this,
					function(){
						if(content_mc._width>0 || content_mc._width!=undefined){
							var h:Number;
							var w:Number;
							var _w = content_mc._width;
							var _h = content_mc._height;
							if(_w>_h){
								h = int(__width * _h/_w);
								w = __width;
							}else{
								h = __height;
								w = int(__height * _w/_h);
							}
							content_mc._width = w;
							content_mc._height = h;
							navigator_mc.clear();
							
							navigator_mc.drawRectangle(w,h,lS,Number(GuideRectangleFillColor),GuideRectangleFillAlpha);
							delete content_mc.onEnterFrame;

						}
					}
				);
					
		}
		public function onEnterFrame(){
			if(pressed && (content_mc.empClip._oldXMouse != content_mc.empClip._xmouse || content_mc.empClip._oldYMouse != content_mc.empClip._ymouse) ){
				MovieSync();
			}
		}
		public function onRelease():Void{
			pressed = false;
			if(content_mc.empClip._oldXMouse == content_mc.empClip._xmouse && content_mc.empClip._oldYMouse == content_mc.empClip._ymouse){
				_instance.ZoomOn(content_mc.empClip._xmouse,content_mc.empClip._ymouse);
			}else{
				_instance.CreateCropedClip();
			}
			pressed = false;
		}

		function onReleaseOutside(){
			ClearEvents();
		}
		public function onPress():Void{
			content_mc.empClip._oldXMouse = content_mc.empClip._xmouse;
			content_mc.empClip._oldYMouse = content_mc.empClip._ymouse;
			_instance.CenterOn(content_mc.empClip._xmouse,content_mc.empClip._ymouse,false,true);
			pressed = true;
		}
		private function ClearEvents():Void{
				_instance.CreateCropedClip();
				pressed = false;
		}
		private function MovieSync(){
			_instance.CenterOn(content_mc.empClip._xmouse,content_mc.empClip._ymouse);
		}
		private function NavigatorEnterFrame(){
			var obj:Object = _instance.getReferenceBounds();
			content_mc.localToGlobal(obj.ponto);
			globalToLocal(obj.ponto);
			navigator_mc._x = obj.ponto.x;
			navigator_mc._y = obj.ponto.y;
			navigator_mc._xscale = navigator_mc._yscale = obj.scale;
			

		}


	}