package fairygui
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.geom.ColorTransform;
	import flash.geom.Point;
	import flash.net.URLRequest;
	
	import fairygui.display.MovieClip;
	import fairygui.display.UISprite;
	import fairygui.utils.ToolSet;

	public class GLoader extends GObject implements IColorGear, IAnimationGear
	{
		private var _gearAnimation:GearAnimation;
		private var _gearColor:GearColor;
		
		private var _url:String;
		private var _align:int;
		private var _verticalAlign:int;
		private var _autoSize:Boolean;
		private var _fill:int;
		private var _showErrorSign:Boolean;
		private var _playing:Boolean;
		private var _frame:int;
		private var _color:uint;
		
		private var _contentItem:PackageItem;
		private var _contentSourceWidth:int;
		private var _contentSourceHeight:int;
		private var _contentWidth:int;
		private var _contentHeight:int;
		
		private var _container:Sprite;
		private var _content:DisplayObject;
		private var _errorSign:GObject;
		
		private var _updatingLayout:Boolean;
		
		private var _loading:int;
		private var _externalLoader:Loader;
		
		private static var _errorSignPool:GObjectPool = new GObjectPool();
		
		public function GLoader()
		{
			_playing = true;
			_url = "";
			_align = AlignType.Left;
			_verticalAlign = VertAlignType.Top;
			_showErrorSign = true;
			_color = 0xFFFFFF;
			
			_gearAnimation = new GearAnimation(this);
			_gearColor = new GearColor(this);
		}
		
		override protected function createDisplayObject():void
		{
			_container = new UISprite(this);
			_container.scaleX = GRoot.contentScaleFactor;
			_container.scaleY = GRoot.contentScaleFactor;
			setDisplayObject(_container);
		}
		
		override public function handleControllerChanged(c:Controller):void
		{
			super.handleControllerChanged(c);
			if(_gearAnimation.controller==c)
				_gearAnimation.apply();
			if(_gearColor.controller==c)
				_gearColor.apply();
		}
		
		public override function dispose():void
		{
			if(_contentItem!=null)
			{
				if(_loading==1)
					_contentItem.owner.removeItemCallback(_contentItem, __imageLoaded);
				else if(_loading==2)
					_contentItem.owner.removeItemCallback(_contentItem, __movieClipLoaded);
			}
			else
			{
				//external
				if(_content!=null)
					freeExternal(_content);
			}
			super.dispose();
		}

		public function get url():String
		{
			return _url;
		}

		public function set url(value:String):void
		{
			if(_url==value)
				return;
			
			_url = value;
			loadContent();
		}
		
		public function get align():int
		{
			return _align;
		}
		
		public function set align(value:int):void
		{
			if(_align!=value)
			{
				_align = value;
				updateLayout();
			}
		}
		
		public function get verticalAlign():int
		{
			return _verticalAlign;
		}
		
		public function set verticalAlign(value:int):void
		{
			if(_verticalAlign!=value)
			{
				_verticalAlign = value;
				updateLayout();
			}
		}
		
		public function get fill():int
		{
			return _fill;
		}
		
		public function set fill(value:int):void
		{
			if(_fill!=value)
			{
				_fill = value;
				updateLayout();
			}
		}		
		
		public function get autoSize():Boolean
		{
			return _autoSize;
		}
		
		public function set autoSize(value:Boolean):void
		{
			if(_autoSize!=value)
			{
				_autoSize = value;
				updateLayout();
			}
		}

		public function get playing():Boolean
		{
			return _playing;
		}
		
		public function set playing(value:Boolean):void
		{
			if(_playing!=value)
			{
				_playing = value;
				if(_content is fairygui.display.MovieClip)
					fairygui.display.MovieClip(_content).playing = value;
				else if(_content is flash.display.MovieClip)
					flash.display.MovieClip(_content).stop();
				if (_gearAnimation.controller != null)
					_gearAnimation.updateState();
			}
		}
		
		public function get frame():int
		{
			return _frame;
		}
		
		public function set frame(value:int):void
		{
			if(_frame!=value)
			{
				_frame = value;
				if(_content is fairygui.display.MovieClip)
					fairygui.display.MovieClip(_content).currentFrame = value;
				else if(_content is flash.display.MovieClip)
				{
					if(_playing)
						flash.display.MovieClip(_content).gotoAndPlay(_frame+1);
					else
						flash.display.MovieClip(_content).gotoAndStop(_frame+1);
				}
				if (_gearAnimation.controller != null)
					_gearAnimation.updateState();
			}
		}
		
		public function get color():uint
		{
			return _color;
		}
		
		public function set color(value:uint):void 
		{
			if(_color != value)
			{
				_color = value;
				if (_gearColor.controller != null)
					_gearColor.updateState();
				applyColor();
			}
		}
		
		private function applyColor():void
		{
			var ct:ColorTransform = _container.transform.colorTransform;
			ct.redMultiplier = ((_color>>16)&0xFF)/255;
			ct.greenMultiplier =  ((_color>>8)&0xFF)/255;
			ct.blueMultiplier = (_color&0xFF)/255;
			_container.transform.colorTransform = ct;
		}

		public function get showErrorSign():Boolean
		{
			return _showErrorSign;
		}
		
		public function set showErrorSign(value:Boolean):void
		{
			_showErrorSign = value;
		}
		
		protected function loadContent():void
		{
			clearContent();
			
			if(!_url)
				return;

			if(ToolSet.startsWith(_url, "ui://"))
				loadFromPackage(_url);
			else
				loadExternal();
		}
		
		protected function loadFromPackage(itemURL:String):void
		{
			_contentItem = UIPackage.getItemByURL(itemURL);
			if(_contentItem!=null)
			{
				if(_contentItem.type==PackageItemType.Image)
				{
					if(_contentItem.loaded)
						__imageLoaded(_contentItem);
					else
					{
						_loading = 1;
						_contentItem.owner.addItemCallback(_contentItem, __imageLoaded);
					}
				}
				else if(_contentItem.type==PackageItemType.MovieClip)
				{
					if(_contentItem.loaded)
						__movieClipLoaded(_contentItem);
					else
					{
						_loading = 2;
						_contentItem.owner.addItemCallback(_contentItem, __movieClipLoaded);
					}
				}
				else
					setErrorState();
			}
			else
				setErrorState();
		}
		
		private function __imageLoaded(pi:PackageItem):void
		{
			_loading = 0;

			if(pi.image==null)
			{
				setErrorState();
			}
			else
			{
				if(!(_content is Bitmap))
				{
					_content = new Bitmap();
					_container.addChild(_content);
				}
				else
					_container.addChild(_content);
				Bitmap(_content).bitmapData = pi.image;
				Bitmap(_content).smoothing = pi.smoothing;
				_contentSourceWidth = pi.width;
				_contentSourceHeight = pi.height;
				updateLayout();
			}
		}
		
		private function __movieClipLoaded(pi:PackageItem):void
		{
			_loading = 0;
			if(!(_content is fairygui.display.MovieClip))
			{
				_content = new fairygui.display.MovieClip();
				_container.addChild(_content);
			}
			else
				_container.addChild(_content);
			fairygui.display.MovieClip(_content).interval = pi.interval;
			fairygui.display.MovieClip(_content).frames = pi.frames;
			_contentSourceWidth = pi.width;
			_contentSourceHeight = pi.height;
			updateLayout();
		}
		
		protected function loadExternal():void
		{
			if(!_externalLoader)
			{
				_externalLoader = new Loader();
				_externalLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, __externalLoadCompleted);
				_externalLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, __externalLoadFailed);
			}
			_externalLoader.load(new URLRequest(url));
		}
		
		protected function freeExternal(content:DisplayObject):void
		{
			
		}
		
		final protected function onExternalLoadSuccess(content:DisplayObject):void
		{
			_content = content;
			_container.addChild(_content);
			if(content.loaderInfo)
			{
				_contentSourceWidth = content.loaderInfo.width;
				_contentSourceHeight =  content.loaderInfo.height;
			}
			else
			{
				_contentSourceWidth = content.width;
				_contentSourceHeight =  content.height;
			}
			updateLayout();
		}
		
		final protected function onExternalLoadFailed():void
		{
			setErrorState();
		}
		
		private function __externalLoadCompleted(evt:Event):void
		{
			onExternalLoadSuccess(_externalLoader.content);
		}
		
		private function __externalLoadFailed(evt:Event):void
		{
			onExternalLoadFailed();
		}

		private function setErrorState():void
		{
			if (!_showErrorSign)
				return;
			
			if (_errorSign == null)
			{
				if (UIConfig.loaderErrorSign != null)
				{
					_errorSign = _errorSignPool.getObject(UIConfig.loaderErrorSign);
				}
			}
			
			if (_errorSign != null)
			{
				_errorSign.width = this.width;
				_errorSign.height = this.height;
				_container.addChild(_errorSign.displayObject);
			}
		}
		
		private function clearErrorState():void
		{
			if (_errorSign != null)
			{
				_container.removeChild(_errorSign.displayObject);
				_errorSignPool.returnObject(_errorSign);
				_errorSign = null;
			}
		}
		
		private function updateLayout():void
		{
			if(_content==null)
			{
				if(_autoSize)
				{
					_updatingLayout = true;
					this.setSize(50, 30);
					_updatingLayout = false;
				}
				return;
			}
			
			_content.x = 0;
			_content.y = 0;
			_content.scaleX = 1;
			_content.scaleY = 1;
			_contentWidth = _contentSourceWidth;
			_contentHeight = _contentSourceHeight;
			
			if(_autoSize)
			{
				_updatingLayout = true;
				if(_contentWidth==0)
					_contentWidth = 50;
				if(_contentHeight==0)
					_contentHeight = 30;
				this.setSize(_contentWidth, _contentHeight);
				_updatingLayout = false;
			}
			else
			{		
				var sx:Number = 1, sy:Number = 1;
				if(_fill==FillType.Scale || _fill==FillType.ScaleFree)
				{
					sx = this.width/_contentSourceWidth;
					sy = this.height/_contentSourceHeight;
					
					if(sx!=1 || sy!=1)
					{
						if(_fill==FillType.Scale)
						{
							if(sx>sy)
								sx = sy;
							else
								sy = sx;
						}
						_contentWidth = _contentSourceWidth * sx;
						_contentHeight = _contentSourceHeight * sy;
					}
				}	
				
				if(_contentItem && _contentItem.type==PackageItemType.Image)
				{
					resizeImage();
				}
				else
				{
					_content.scaleX =  sx;
					_content.scaleY =  sy;
				}
				
				if(_align==AlignType.Center)
					_content.x = int((this.width-_contentWidth)/2);
				else if(_align==AlignType.Right)
					_content.x = this.width-_contentWidth;
				if(_verticalAlign==VertAlignType.Middle)
					_content.y = int((this.height-_contentHeight)/2);
				else if(_verticalAlign==VertAlignType.Bottom)
					_content.y = this.height-_contentHeight;
			}
		}
		
		private function clearContent():void 
		{
			clearErrorState();
			
			if(_content!=null && _content.parent!=null) 
				_container.removeChild(_content);
			
			if(_contentItem!=null)
			{
				if(_loading==1)
					_contentItem.owner.removeItemCallback(_contentItem, __imageLoaded);
				else if(_loading==2)
					_contentItem.owner.removeItemCallback(_contentItem, __movieClipLoaded);
			}
			else
			{
				if(_content!=null)
					freeExternal(_content);
			}
			
			_contentItem = null;
			_loading = 0;
		}
		
		override protected function handleSizeChanged():void
		{
			if(!_updatingLayout)
				updateLayout();
			
			_container.scaleX = this.scaleX * GRoot.contentScaleFactor;
			_container.scaleY = this.scaleY * GRoot.contentScaleFactor;
		}
		
		private function resizeImage():void
		{
			var source:BitmapData = _contentItem.image;
			if(source==null)
				return;
			
			if(_contentItem.scale9Grid!=null)
			{
				_content.scaleX = 1;
				_content.scaleY = 1;
				
				var oldBmd:BitmapData = Bitmap(_content).bitmapData;
				var newBmd:BitmapData;
				
				if(source.width==this.width && source.height==this.height)
					newBmd = source;
				else if(this.width==0 || this.height==0)
					newBmd = null;
				else
					newBmd = ToolSet.scaleBitmapWith9Grid(source, 
						_contentItem.scale9Grid, this.width, this.height, _contentItem.smoothing);
				
				if(oldBmd!=newBmd)
				{
					if(oldBmd && oldBmd!=source)
						oldBmd.dispose();
					Bitmap(_content).bitmapData = newBmd;
				}
			}
			else if(_contentItem.scaleByTile)
			{
				_content.scaleX = 1;
				_content.scaleY = 1;
				
				oldBmd = Bitmap(_content).bitmapData;
				
				if(source.width==this.width && source.height==this.height)
					newBmd = source;
				else if(this.width==0 || this.height==0)
					newBmd = null;
				else
				{
					newBmd = new BitmapData(this.width, this.height, source.transparent, 0);
					var hc:int = Math.ceil(this.width/source.width);
					var vc:int = Math.ceil(this.height/source.height);
					var pt:Point = new Point();
					for(var i:int=0;i<hc;i++)
					{
						for(var j:int=0;j<vc;j++)
						{
							pt.x = i*source.width;
							pt.y = j*source.height;
							newBmd.copyPixels(source, source.rect, pt);
						}
					}
				}
				
				if(oldBmd!=newBmd)
				{
					if(oldBmd && oldBmd!=source)
						oldBmd.dispose();
					Bitmap(_content).bitmapData = newBmd;
				}
			}
			else
			{
				_content.scaleX = _contentWidth/_contentSourceWidth;
				_content.scaleY = _contentHeight/_contentSourceHeight;
			}
		}
		
		override public function setup_beforeAdd(xml:XML):void
		{
			super.setup_beforeAdd(xml);
			
			var str:String;
			str = xml.@url;
			if(str)
				_url = str;
			
			str = xml.@align;
			if(str)
				_align = AlignType.parse(str);
			
			str = xml.@vAlign;
			if(str)
				_verticalAlign = VertAlignType.parse(str);
			
			str = xml.@fill;
			if(str)
				_fill = FillType.parse(str);
			
			_autoSize = xml.@autoSize=="true";
			
			str = xml.@errorSign;
			if(str)
				_showErrorSign = str=="true";
			
			_playing = xml.@playing != "false";
			
			str = xml.@color;
			if(str)
				this.color = ToolSet.convertFromHtmlColor(str);
			
			if(_url)
				loadContent();
		}
		
		override public function setup_afterAdd(xml:XML):void
		{
			super.setup_afterAdd(xml);
			
			var cxml:XML = xml.gearAni[0];
			if(cxml)
				_gearAnimation.setup(cxml);
			cxml = xml.gearAni[0];
			cxml = xml.gearColor[0];
			if(cxml)
				_gearColor.setup(cxml);
		}
	}
}