package;

import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import neko.Lib;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
import openfl.display.BitmapData;
import openfl.utils.ByteArray;
import sys.io.FileInput;
import sys.io.FileOutput;

class Main 
{
	static function main() 
	{
		//getAlts('players/player1.png');
		
		var spriteFiles:Array<String> = FileSystem.readDirectory('players');
		
		for (file in spriteFiles)
		{
			//convertSprite(Path.join(['fullshot', file]));
			getAlts(Path.join(['players', file]));
		}
	}
	
	static function convertSprite(path:String)
	{
		trace(path);
		var spriteSheet:BitmapData = getBitmap(path);
		var fname:String = Path.withoutExtension(Path.withoutDirectory(path));
		var palSub:String = '';
		//palSub = fname.substr(16);
		
		switch(Std.parseInt(fname.charAt(6)))
		{
			case 0:
				palSub = 'kid';
			case 1:
				palSub = 'robot';
			case 2:
				palSub = 'candy';
			case 3:
				palSub = 'boom';
			case 4:
				palSub = 'croc';
			case 7:
				palSub = 'pong';
		}
		
		var palette:BitmapData = getBitmap('characters/$palSub/4/0.png');
		
		for (i in 0...64)
		{
			
			spriteSheet.threshold(spriteSheet, spriteSheet.rect, new Point(0, 0), '==', (0xFF << 24) + (i << 16), palette.getPixel32(i, 0));
		}
		
		savePNG('outFullshot/$palSub.png', spriteSheet);
	}
	
	static function getAlts(path:String)
	{
		var fname:String = Path.withoutExtension(Path.withoutDirectory(path));
		var palSub:String = '';
		
		switch(Std.parseInt(fname.charAt(6)))
		{
			case 0:
				palSub = 'kid';
			case 1:
				palSub = 'robot';
			case 2:
				palSub = 'candy';
			case 3:
				palSub = 'boom';
			case 4:
				palSub = 'croc';
			case 5:
				palSub = 'pong';
		}
		
		var frameSize:Int = (palSub == 'croc') ? 250 : 200;
		
		var firstFrame:BitmapData = new BitmapData(256, frameSize + 36, true, 0);
		firstFrame.copyPixels(getBitmap(path), new Rectangle(0, 0, frameSize, frameSize), new Point((256 / 2) - (frameSize / 2), 0));
		
		var palDirs:Array<String> = FileSystem.readDirectory('characters/$palSub');
		
		var empty:BitmapData = getBitmap('emptycol.png');
		
		for (dir in palDirs)
		{
			var pals:Array<String> = FileSystem.readDirectory(Path.join(['characters/$palSub', dir]));
			
			for (palFile in pals)
			{
				var outPath:String = Path.join(['alts/$palSub', dir, palFile]);
				trace(outPath);
				
				var outFrame:BitmapData = new BitmapData(firstFrame.width, firstFrame.height, true, 0);
				outFrame.copyPixels(firstFrame, firstFrame.rect, new Point(0, 0));
				var palette:BitmapData = getBitmap(Path.join(['characters/$palSub', dir, palFile]));
				
				var x:Int = 0;
				var y:Int = 0;
				
				for (i in 0...palette.width)
				{
					var col:Int = palette.getPixel32(i, 0);
					outFrame.threshold(outFrame, outFrame.rect, new Point(0, 0), '==', (0xFF << 24) + (i << 16), col);
					
					if (col >> 24 == 0)
						outFrame.copyPixels(empty, empty.rect, new Point(x * 8, frameSize + 10 + (y * 8)));
					else
						outFrame.fillRect(new Rectangle(x * 8, frameSize + 10 + (y * 8), 8, 8), col);
					
					if (++x == 32)
					{
						x = 0;
						y++;
					}
				}
				
				savePNG(outPath, outFrame);
				
				outFrame.dispose();
			}
		}
	}
	
	static function getBitmap(path:String):BitmapData
	{
		var f:FileInput = File.read(path);
		var r:Reader = new Reader(f);
		var dat:Data = r.read();
		f.close();
		
		var header:Header = Tools.getHeader(dat);
		var pxlBytes:Bytes = Tools.extract32(dat);
		Tools.reverseBytes(pxlBytes);
		
		var bmp:BitmapData = new BitmapData(header.width, header.height, true, 0);
		bmp.setPixels(bmp.rect, ByteArray.fromBytes(pxlBytes));
		
		return bmp;
	}
	
	static function savePNG(path:String, bmp:BitmapData)
	{
		FileSystem.createDirectory(Path.directory(path));
		
		var bytes:Bytes = Bytes.ofData(bmp.getPixels(bmp.rect));
		
		var f:FileOutput = File.write(path);
		var w:Writer = new Writer(f);
		var dat:Data = Tools.build32ARGB(bmp.width, bmp.height, bytes);
		w.write(dat);
		f.close();
	}
}