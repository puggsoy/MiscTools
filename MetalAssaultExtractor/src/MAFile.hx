package ;
class MAFile
{
	public var path:String;
	public var zsize:Int;
	public var size:Int;
	public var unk:Int;
	public var endOff:Int;
	public var offset:Int;
	
	public function new() 
	{
		path = "";
		offset = 0;
		zsize = 0;
		size = 0;
	}
}