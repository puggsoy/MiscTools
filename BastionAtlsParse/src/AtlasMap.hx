package;
import sys.io.FileInput;

class AtlasMap
{
	public var mapName:String;
	public var frameX:Int;
	public var frameY:Int;
	public var frameWidth:Int;
	public var frameHeight:Int;
	public var animX:Int;
	public var animY:Int;
	public var originalWidth:Int;
	public var originalHeight:Int;
	public var scaleX:Float;
	public var scaleY:Float;
	
	public function new(f:FileInput)
	{
		var be:Bool = f.bigEndian;
		f.bigEndian = false;
		
		var len:Int = f.readByte();
		mapName = f.readString(len);
		frameX = f.readInt32();
		frameY = f.readInt32();
		frameWidth = f.readInt32();
		frameHeight = f.readInt32();
		animX = f.readInt32();
		animY = f.readInt32();
		originalWidth = f.readInt32();
		originalHeight = f.readInt32();
		scaleX = f.readFloat();
		scaleY = f.readFloat();
		
		f.bigEndian = be;
	}
}