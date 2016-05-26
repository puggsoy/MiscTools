package ;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.geom.Point;
import format.png.Data;
import format.png.Tools;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import sys.io.File;
import sys.io.FileOutput;

/**
 * ...
 * @author Puggsoy
 */
class BARImage
{
	public var imageChunks:Array<ImgChunk>;
	public var imgWidth:UInt;
	public var imgHeight:UInt;
	
	public function new() 
	{
		
	}
	
	public function getData():Data
	{
		var bitmapData:BitmapData = new BitmapData(imgWidth, imgHeight, true, 0);
		var tempDat:BitmapData;
		
		for (i in 0...imageChunks.length)
		{
			var chunk:ImgChunk = imageChunks[i];
			tempDat = new BitmapData(chunk.w, chunk.h, true, 0);
			
			var pixBytes:BytesInput = new BytesInput(chunk.pixelData);
			pixBytes.bigEndian = true;
			
			for (y in 0...chunk.h)
			{
				for (x in 0...chunk.w)
				{
					tempDat.setPixel32(x, y, readUInt32(pixBytes));
				}
			}
			
			bitmapData.copyPixels(tempDat, tempDat.rect, new Point(chunk.x, chunk.y));
		}
		
		var bitmapBytes:Bytes = bitmapData.getPixels(bitmapData.rect);
		
		var pixBytes:BytesOutput = new BytesOutput();
		pixBytes.writeBytes(bitmapBytes, 0, bitmapBytes.length);
		
		var data:Data = Tools.build32ARGB(imgWidth, imgHeight, pixBytes.getBytes());
		
		return data;
	}
	
	private function readUInt32(input:BytesInput):UInt
	{
		var first:UInt = input.readUInt16();
		var second:UInt = input.readUInt16();
		
		if (!input.bigEndian)
		{
			second <<= 16;
		}
		else
		{
			first <<= 16;
		}
		
		return first + second;
	}
}