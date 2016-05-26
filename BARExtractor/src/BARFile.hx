package ;
import flash.utils.ByteArray;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.Log;
import haxe.Timer;

/**
 * ...
 * @author Puggsoy
 */
class BARFile
{
	private var _length:Int;
	private var _images:Array<BARImage>;
	
	private var _main:Main;
	
	public function new(input:BytesInput, len:Int, main:Main) 
	{
		_length = len;
		_images = new Array<BARImage>();
		
		_main = main;
		
		moveToImageHeader(input);
	}
	
	private function moveToImageHeader(input:BytesInput)
	{
		input.bigEndian = true;
		
		while ((_length - input.position) > 35)
		{
			if (input.readByte() == 0xDF)
			{
				input.position--;
				
				var stamp1:UInt = input.readUInt16();
				var stamp2:UInt = readUInt32(input);
				
				if (stamp1 == 0xDF05 && stamp2 == 0x39250100)
				{
					Log.trace("found image header at position " + StringTools.hex(input.position));
					getImage(input);
					
					return;
				}
				
				input.position - 5;
			}
		}
		
		done();
	}
	
	private function getImage(input:BytesInput)
	{
		var currentImage:BARImage = new BARImage();
		currentImage.imageChunks = new Array<ImgChunk>();
		
		input.bigEndian = false;
		
		var chunkNum:UInt = input.readUInt16();
		var chunk:ImgChunk;
		
		var width:Int = 0;
		var height:Int = 0;
		
		for (i in 0...chunkNum)
		{
			if (input.readByte() != 0x00)
			{
				abort("Bad separator at position " + (input.position - 1));
			}
			
			chunk = new ImgChunk();
			chunk.x = input.readUInt16();
			chunk.y = input.readUInt16();
			chunk.w = input.readUInt16();
			chunk.h = input.readUInt16();
			
			if (width < chunk.x + chunk.w)
			{
				width = chunk.x + chunk.w;
			}
			
			if (height < chunk.y + chunk.h)
			{
				height = chunk.y + chunk.h;
			}
			
			currentImage.imageChunks.push(chunk);
		}
		
		currentImage.imgWidth = width;
		currentImage.imgHeight = height;
		
		Log.trace("dimensions: " + currentImage.imgWidth + "x" + currentImage.imgHeight);
		
		moveToPixelData(input);
		
		for (i in 0...chunkNum)
		{
			var pixelDatLength:Int = readUInt32(input);
			currentImage.imageChunks[i].pixelData = Bytes.alloc(pixelDatLength);
			input.readBytes(currentImage.imageChunks[i].pixelData, 0, pixelDatLength);
		}
		
		_images.push(currentImage);
		
		moveToImageHeader(input);
	}
	
	private function readUInt32(input:BytesInput):UInt
	{
		var first:UInt = input.readUInt16();
		var second:UInt = input.readUInt16();
		
		if (input.bigEndian)
		{
			first <<= 16;
		}
		else
		{
			second <<= 16;
		}
		
		return first + second;
	}
	
	private function moveToPixelData(input:BytesInput)
	{
		while ((_length - input.position) > 0)
		{
			if (input.readByte() == 0x88)
			{
				input.position--;
				
				if (readUInt32(input) == 0x00AA8888)
				{
					Log.trace("found pixel data at position " + StringTools.hex(input.position));
					return;
				}
				
				input.position -= 3;
			}
		}
		
		abort("End of file reached when looking for pixel data");
	}
	
	private function done()
	{
		if (_images.length < 1)
		{
			Log.trace("No images found in BAR!");
		}
		else
		{
			Log.trace("done reading BAR file, " + _images.length + " images found");
			_main.saveFiles(_images);
		}
	}
	
	private function abort(reason:String)
	{
		Log.trace("ABORTING PROCESS. REASON: " + reason);
		Sys.exit(3);
	}
}