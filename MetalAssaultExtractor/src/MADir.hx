package ;
class MADir
{
	public var path:String;
	public var dirs:Array<MADir>;
	public var files:Array<MAFile>;
	
	public var start:Int;
	public var end:Int;
	
	public function new() 
	{
		path = "";
		dirs = new Array<MADir>();
		files = new Array<MAFile>();
	}
}