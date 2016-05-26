package ;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	static private var f:FileInput;
	static private var outDir:String;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = "Usage: CosmicBugExt inFile outDir\n    inFile: The corresponding .bbk file of the file to extract. Can alternatively be a folder containing multiple of these\n    outDir: The folder to save the extracted files to";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	static private function checkArgs()
	{
		outDir = Begin.args[1];
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.anyKeyExit(1, "outDir must be a directory!");
		}
		
		if (FileSystem.isDirectory(Begin.args[0]))
		{
			var files:Array<String> = FileSystem.readDirectory(Begin.args[0]);
			
			for (file in files)
			{
				if (file.substr( -4, 4) == ".bbk")
				{
					loadFile(Begin.args[0] + "/" + file);
				}
			}
		}
		else
		{
			loadFile(Begin.args[0]);
		}
		
		End.anyKeyExit(0, "Done");
	}
	
	static private function loadFile(path:String)
	{
		Sys.println('Loading $path');
		
		var bank:Xml = Xml.parse(File.getContent(path)).firstElement();
		
		if (bank.nodeName != 'BANK') End.anyKeyExit(1, 'Expected BANK, got ${bank.nodeName}');
		
		var datFile:String = bank.get('datafile');
		datFile = Path.join([Path.directory(path), datFile]);
		
		if(!FileSystem.exists(datFile)) End.anyKeyExit(1, '$datFile must be in the same directory!');
		
		var bankElems:Iterator<Xml> = bank.elements();
		
		var imageList:Xml = bankElems.next();
		
		if (imageList.nodeName != 'IMAGELIST') End.anyKeyExit(1, 'Expected IMAGELIST, got ${imageList.nodeName}');
		
		var paletteList:Xml = bankElems.next();
		
		if (paletteList.nodeName != 'PALETTELIST') End.anyKeyExit(1, 'Expected PALETTELIST, got ${paletteList.nodeName}');
		
		var palettes:Array<Array<Int>> = new Array<Array<Int>>();
		
		var paletteElems:Iterator<Xml> = paletteList.elements();
		
		for (e in paletteElems)
		{
			var str:String = e.firstChild().toString();
			var vals:Array<String> = str.split(' ');
			
			var pal:Array<Int> = new Array<Int>();
			
			var i:Int = 0;
			var colorNum:Int = Std.parseInt(e.get('colorsUsed'));
			
			while(i < colorNum)
			{
				var v:Int = Std.parseInt(vals.shift());
				
				if (v != null)
				{
					var a:Int = 0xFF;
					var r:Int = v & 0xFF;
					v = Std.parseInt(vals.shift());
					var g:Int = v & 0xFF;
					v = Std.parseInt(vals.shift());
					var b:Int = v & 0xFF;
					
					var argb:Int = (a << 24) + (r << 16) + (g << 8) + b;
					
					pal.push(argb);
					
					i++;
				}
			}
			
			palettes.push(pal);
		}
		
		f = File.read(datFile);
		f.bigEndian = true;
		
		var imageElems:Iterator<Xml> = imageList.elements();
		
		for (e in imageElems)
		{
			var name:String = e.get('name');
			var offset:Int = Std.parseInt(e.get('dataOffset'));
			var size:Int = Std.parseInt(e.get('dataSize'));
			var bpp:Int = Std.parseInt(e.get('bpp'));
			var width:Int = Std.parseInt(e.get('width'));
			var height:Int = Std.parseInt(e.get('height'));
			var palNum:Int = Std.parseInt(e.get('paletteNumber'));
			
			var imgOut:BytesOutput = new BytesOutput();
			imgOut.bigEndian = true;
			f.seek(offset, FileSeek.SeekBegin);
			
			while (f.tell() < (offset + size))
			{
				if (bpp == 32)
				{
					var rgb:Int = f.readInt24();
					var a:Int = f.readByte();
					var argb:Int = (a << 24) + rgb;
					imgOut.writeInt32(argb);
				}
				else
				if (bpp == 8)
				{
					var p:Int = f.readByte();
					imgOut.writeInt32(palettes[palNum][p]);
				}
			}
			
			var outPath = Path.join([outDir, Path.withoutDirectory(Path.withoutExtension(datFile)), '$name.png']);
			
			FileSystem.createDirectory(Path.directory(outPath));
			
			var filename:String = '$name.png';
			
			var pngDat:Data = Tools.build32ARGB(width, height, imgOut.getBytes());
			var o:FileOutput = File.write(outPath);
			var w:Writer = new Writer(o);
			Sys.println('Saving $outPath');
			w.write(pngDat);
			o.close();
		}
		
		f.close();
	}
}