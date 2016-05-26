package ;
import haxe.io.Bytes;

/**
 * ...
 * @author Puggsoy
 */
class Entry
{
	public var nameLength:UInt;
	public var compressedName:Bytes;
	public var name:String;
	public var offset:UInt;
	public var size:UInt;
	
	public function new() 
	{
		
	}
	
}