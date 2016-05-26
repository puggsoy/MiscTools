package;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import format.swf.Data.Rect;
import haxe.io.Bytes;
import haxe.io.Path;
import neko.Lib;
import openfl.display.BitmapData;
import openfl.display.BitmapDataChannel;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	private var animName:String;
	private var columns:Int = 0;
	private var dividerSz:Int = 0;
	private var includeEmpty:Bool = false;
	private var inDir:String = '.';
	private var outDir:String = '.';
	
	private function new() 
	{
		Begin.init();
		Begin.usage = 'Usage: FFBETool num [-a anim] [-c columns] [-d divider thickness] [-e] [-i inDir] [-o outDir]\n\nArguments:\n    num: The number at the end of the .png and .csv files of the sprite of interest\n    [-a]: Specifies a specific .csv animation to extract. For example for "unit_magic_atk_cgs_100000102.csv" you would use "magic_atk". Omit to extract all animations found\n    [-c]: The number of columns the animation should be organised into. Omit to just have a single linear strip\n    [-d]: The thickness (in pixels) of the divider between frames. Omit to not have any dividers\n    [-e]: Use this to include empty frames. Omit to ignore them\n    [-i]: The folder containing the input files. Omit to use the same directory as this executable\n    [-o]: The same as -i, but for the resulting output files';
		Begin.functions = [null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		var args:Array<String> = Begin.args;
		
		for (i in 1...args.length)
		{
			switch(args[i])
			{
				case '-a':
					animName = args[i + 1];
				case '-c':
					columns = Std.parseInt(args[i + 1]);
				case '-d':
					dividerSz = Std.parseInt(args[i + 1]);
				case '-e':
					includeEmpty = true;
				case '-i':
					inDir = args[i + 1];
				case '-o':
					outDir = args[i + 1];
			}
		}
		
		var id:String = args[0];
		
		readCgg(id);
		
		End.terminate(0, 'All done!');
	}
	
	/**
	 * Checks that cgg and png exist and loads them, then proceeds to call makeStrip for each cgs
	 * @param	unitID
	 */
	private function readCgg(unitID:String)
	{
		var cggPath:String = '$inDir/unit_cgg_$unitID.csv';
		var pngPath:String = '$inDir/unit_anime_$unitID.png';
		
		if (!FileSystem.exists(cggPath))
		{
			Sys.println('$cggPath doesn\'t exist!');
			return;
		}
		
		if (!FileSystem.exists(pngPath))
		{
			Sys.println('$pngPath doesn\'t exist!');
			return;
		}
		
		Sys.println('Loading $cggPath...');
		
		var f:FileInput = File.read(cggPath);
		f.seek(0, FileSeek.SeekEnd);
		var fSize:Int = f.tell();
		f.seek(0, FileSeek.SeekBegin);
		
		var frames:Array<Array<CggPart>> = new Array<Array<CggPart>>();
		
		while (f.tell() < fSize)
		{
			var line:String = f.readLine();
			var params:Array<String> = line.split(',');
			
			if (params.length < 2) break;
			
			var anchor:Int = Std.parseInt(params[0]);
			var count:Int = Std.parseInt(params[1]);
			
			var parts:Array<CggPart> = new Array<CggPart>();
			var i:Int = 2;
			
			for (partInd in 0...count)
			{
				var part:CggPart = new CggPart();
				
				part.xPos = Std.parseInt(params[i++]);
				part.yPos = Std.parseInt(params[i++]);
				part.nextType = Std.parseInt(params[i++]);
				part.flipX = false;
				part.flipY = false;
				
				switch(part.nextType)
				{
					case 0:
					case 1: part.flipX = true;
					case 2: part.flipY = true;
					case 3: part.flipX = part.flipY = true;
					default:
						Sys.println("Invalid next type!");
						return;
				}
				
				part.blendMode = Std.parseInt(params[i++]);
				part.opacity = Std.parseFloat(params[i++]);
				part.rotate = Std.parseInt(params[i++]);
				part.imgX = Std.parseInt(params[i++]);
				part.imgY = Std.parseInt(params[i++]);
				part.imgWidth = Std.parseInt(params[i++]);
				part.imgHeight = Std.parseInt(params[i++]);
				part.pageID = Std.parseInt(params[i++]);
				
				parts.push(part);
			}
			
			parts.reverse();
			frames.push(parts);
		}
		
		f.close();
		
		Sys.println('Loading $pngPath...');
		f = File.read(pngPath);
		
		var d:Data = new Reader(f).read();
		var h:Header = Tools.getHeader(d);
		var b:Bytes = Tools.extract32(d);
		Tools.reverseBytes(b);
		f.close();
		
		var img:BitmapData = new BitmapData(h.width, h.height, true, 0);
		img.setPixels(img.rect, ByteArray.fromBytes(b));
		
		if (animName != null)
		{
			var cgsPath:String = '$inDir/unit_${animName}_cgs_$unitID.csv';
			
			if (!FileSystem.exists(cgsPath))
			{
				Sys.println('$cgsPath doesn\'t exist!');
				return;
			}
			
			makeStrip('$inDir/unit_${animName}_cgs_$unitID.csv', frames, img);
		}
		else
		{
			for (file in FileSystem.readDirectory(inDir))
			{
				if (!FileSystem.isDirectory('$inDir/$file') &&
					Path.extension(file).toLowerCase() == "csv" &&
					Path.withoutExtension(file).indexOf('cgs_') != -1 &&
					Path.withoutExtension(file).indexOf(unitID) != -1)
				{
					makeStrip('$inDir/$file', frames, img);
				}
			}
		}
	}
	
	/**
	 * Cuts the sprites from the source image using information from a cgs and cgg data and turns them into a strip
	 * @param	cgsPath
	 * @param	frames
	 * @param	pngName
	 */
	private function makeStrip(cgsPath:String, frames:Array<Array<CggPart>>, img:BitmapData)
	{
		Sys.println('Loading $cgsPath...');
		var f:FileInput = File.read(cgsPath);
		f.seek(0, FileSeek.SeekEnd);
		var fSize:Int = f.tell();
		f.seek(0, FileSeek.SeekBegin);
		
		Sys.println('Constructing frames...');
		
		var topLeft:Point = null;
		var botRight:Point = null;
		var frameImgs:Array<BitmapData> = new Array<BitmapData>();
		
		while (f.tell() < fSize)
		{
			var line:String = f.readLine();
			var params:Array<String> = line.split(',');
			
			if (params.length < 2) break;
			
			var frameIndex:Int = Std.parseInt(params[0]);
			var xPos:Int = Std.parseInt(params[1]);
			var yPos:Int = Std.parseInt(params[2]);
			var delay:Int = Std.parseInt(params[3]);
			
			var frameImg:BitmapData = new BitmapData(2000, 2000, true, 0);
			
			for (part in frames[frameIndex])
			{
				var box:Rectangle = new Rectangle(part.imgX, part.imgY, part.imgWidth, part.imgHeight);
				var crop:BitmapData = new BitmapData(part.imgWidth, part.imgHeight, true, 0);
				crop.copyPixels(img, box, new Point(0, 0), null, null, true);
				
				if (part.blendMode == 1)
				{
					blend(crop);
				}
				if (part.rotate != 0)
				{
					crop = rotate(crop, part.rotate);
				}
				if (part.flipX)
				{
					crop = flip(crop, false);
				}
				if (part.flipY)
				{
					crop = flip(crop, true);
				}
				if (part.opacity != 100)
				{
					crop.colorTransform(crop.rect, new ColorTransform(1, 1, 1, part.opacity / 100));
				}
				
				frameImg.copyPixels(crop, crop.rect, new Point(2000 / 2 + part.xPos + xPos, 2000 / 2 + part.yPos + yPos), null, null, true);
			}
			
			var rect:Rectangle = frameImg.getColorBoundsRect(0xFF000000, 0, false);
			
			if (rect.width == 0 || rect.height == 0)
			{
				if (includeEmpty)
				{
					frameImgs.push(frameImg);
					Sys.println('Frame ${frameImgs.length} done');
				}
				
				continue;
			}
			
			frameImgs.push(frameImg);
			
			if (topLeft == null)
			{
				topLeft = new Point(rect.x, rect.y);
				botRight = new Point(rect.x + rect.width, rect.y + rect.height);
			}
			else
			{
				topLeft.x = Math.min(rect.x, topLeft.x);
				topLeft.y = Math.min(rect.y, topLeft.y);
				botRight.x = Math.max(rect.x + rect.width, botRight.x);
				botRight.y = Math.max(rect.y + rect.height, botRight.y);
			}
			
			Sys.println('Frame ${frameImgs.length} done');
		}
		
		Sys.println('Making strip...');
		
		var frameRect:Rectangle = new Rectangle(topLeft.x - 5, topLeft.y - 5, botRight.x - topLeft.x + 10, botRight.y - topLeft.y + 10);
		var animImg:BitmapData = null;
		var tmpCols:Int = columns;
		
		if (columns == 0 || columns >= frameImgs.length)
		{
			columns = frameImgs.length;
			animImg = new BitmapData((frameImgs.length * Std.int(frameRect.width + dividerSz)) - dividerSz, Std.int(frameRect.height), true, 0);
			
			for (i in 0...frameImgs.length)
			{
				animImg.copyPixels(frameImgs[i], frameRect, new Point(i * (frameRect.width + dividerSz), 0), null, null, true);
			}
		}
		else
		{
			var rows:Int = Math.ceil(frameImgs.length / columns);
			animImg = new BitmapData((columns * Std.int(frameRect.width)) + ((columns - 1) * dividerSz), (rows * Std.int(frameRect.height)) + ((rows - 1) * dividerSz), true, 0);
			
			for (i in 0...rows)
			{
				for (j in 0...columns)
				{
					animImg.copyPixels(frameImgs[(i * columns) + j], frameRect, new Point(j * (frameRect.width + dividerSz), i * (frameRect.height + dividerSz)), null, null, true);
				}
			}
			
			if (dividerSz > 0) addDividers(animImg, frameRect, rows);
		}
		
		if (dividerSz > 0) addDividers(animImg, frameRect, 0);
		
		columns = tmpCols;
		
		if(outDir != '.') FileSystem.createDirectory(outDir);
		
		var cgsBits:Array<String> = Path.withoutExtension(Path.withoutDirectory(cgsPath)).split('cgs_');
		var outName:String = outDir + '/' + cgsBits[0] + cgsBits[1] + '.png';
		
		savePNG(animImg, outName);
		
		Sys.println('Strip saved to $outName');
	}
	
	/**
	 * 
	 * @param	img
	 * @param	frameRect
	 * @param	rows
	 */
	private function addDividers(img:BitmapData, frameRect:Rectangle, rows:Int)
	{
		if (rows > 0)
		{
			for (r in 0...rows)
			{
				img.fillRect(new Rectangle(0, r * (frameRect.height) - dividerSz, img.width, dividerSz), 0xFF000000);
			}
		}
		else
		{
			for (c in 0...columns)
			{
				img.fillRect(new Rectangle(c * (frameRect.width + dividerSz) - dividerSz, 0, dividerSz, img.height), 0xFF000000);
			}
		}
	}
	
	private function blend(img:BitmapData)
	{
		img.lock();
		for (y in 0...img.height)
		{
			for (x in 0...img.width)
			{
				var pix:Int = img.getPixel32(x, y);
				var a:Int = (pix >> 24) & 0xFF;
				
				if (a == 0) continue;
				
				var r:Int = (pix >> 16) & 0xFF;
				var g:Int = (pix >> 8) & 0xFF;
				var b:Int = pix & 0xFF;
				a = Std.int((r + g + b) / 3);
				
				img.setPixel32(x, y, Std.int((a << 24) + (r << 16) + (g << 8) + b));
			}
		}
		img.unlock();
	}
	
	private function rotate(img:BitmapData, degrees:Int):BitmapData
	{
		//return img;
		var newImg:BitmapData = new BitmapData(img.width, img.height, true, 0);
		
		var rads:Float = degrees / 180 * Math.PI;
		var centerX:Float = img.width / 2;
		var centerY:Float = img.height / 2;
		
		for (y in 0...img.height)
		{
			for (x in 0...img.width)
			{
				var dx:Float = x - centerX;
				var dy:Float = y - centerY;
				var newX:Float = Math.cos(rads) * dx - Math.sin(rads) * dy + centerX;
				var newY:Float = Math.cos(rads) * dy + Math.sin(rads) * dx + centerY;
				
				var ix:Int = Math.round(newX);
				var iy:Int = Math.round(newY);
				
				newImg.setPixel32(x, y, img.getPixel32(ix, iy));
			}
		}
		
		return newImg;
		//newImg.copyPixels(img, img.rect, new Point());
		
		/*if (degrees == 90)
		{
			for (y in 0...img.height)
			{
				for (x in 0...img.width)
				{
					newImg.setPixel32(newImg.width - y - 1, x, img.getPixel32(x, y));
				}
			}
		}
		else
		if (degrees == -90 || degrees == 270)
		{
			for (y in 0...img.height)
			{
				for (x in 0...img.width)
				{
					newImg.setPixel32(y, newImg.height - x - 1, img.getPixel32(x, y));
				}
			}
		}
		else
		if (degrees == 180)
		{
			newImg = new BitmapData(img.width, img.height, true, 0);
			
			for (y in 0...img.height)
			{
				for (x in 0...img.width)
				{
					newImg.setPixel32(newImg.width - x - 1, newImg.height - y - 1, img.getPixel32(x, y));
				}
			}
		}
		else
		{
			Sys.println("Invalid rotation!");
			return img;
		}*/
		
		//return newImg;
	}
	
	private function flip(img:BitmapData, vert:Bool):BitmapData
	{
		var newImg:BitmapData = new BitmapData(img.width, img.height, true, 0);
		
		if (vert)
		{
			for (y in 0...img.height)
			{
				for (x in 0...img.width)
				{
					newImg.setPixel32(x, newImg.height - y - 1, img.getPixel32(x, y));
				}
			}
		}
		else
		{
			for (y in 0...img.height)
			{
				for (x in 0...img.width)
				{
					newImg.setPixel32(newImg.width - x - 1, y, img.getPixel32(x, y));
				}
			}
		}
		
		return newImg;
	}
	
	private function savePNG(img:BitmapData, fileName:String)
	{
		var pngDat:Data = Tools.build32ARGB(img.width, img.height, img.getPixels(img.rect));
		var o:FileOutput = File.write(fileName);
		var w:Writer = new Writer(o);
		w.write(pngDat);
		o.close();
	}
	
	static function main() 
	{
		new Main();
	}
}