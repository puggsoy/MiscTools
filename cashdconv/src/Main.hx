package ;

import console.Begin;
import console.End;
import format.neko.Templo.ABuffer;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.Timer;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	static private var parentDir:String;
	static private var palettes:Array<Array<Int>>;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = "Usage: cashdconv palFile imgFile [outDir]\n    palFile: The .col file containing palettes you want to use.\n    imgFile: The .csr file you want to convert. Can alternatively be a folder multiple .csr files\n    outDir: The folder to save the converted files to. If ommitted will create a subfolder called 'converted'";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	static private function checkArgs()
	{
		var outDir:String = (Begin.args.length > 2) ? Path.addTrailingSlash(Begin.args[2]) : null;
		
		if (outDir != null && FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(1, "outDir must be a directory!");
		}
		
		if (!FileSystem.exists(Begin.args[0]))
		{
			End.terminate(2, "palFile must exist!");
		}
		else
		if (FileSystem.isDirectory(Begin.args[0]))
		{
			End.terminate(2, "palFile cannot be a directory!");
		}
		
		if (FileSystem.isDirectory(Begin.args[1]))
		{
			var files:Array<String> = FileSystem.readDirectory(Begin.args[1]);
			var paths:Array<String> = new Array<String>();
			
			for (file in files)
			{
				if (Path.extension(file).toLowerCase() == "csr")
				{
					paths.push(Begin.args[1] + "/" + file);
				}
			}
			
			loadFile(Begin.args[0], paths, outDir);
		}
		else
		{
			loadFile(Begin.args[0], [Begin.args[1]], outDir);
		}
		
		End.terminate(0, "Done");
	}
	
	static private function loadFile(colPath:String, csrPaths:Array<String>, outDir:String)
	{
		readPalette(colPath);
		
		if (outDir == null) outDir = Path.withoutExtension(Path.withoutDirectory("converted")) + "/";
		
		for (path in csrPaths)
		{
			convertImage(path, outDir);
		}
	}
	
	static private function readPalette(col:String)
	{
		if (Path.extension(col) != "col")
		{
			End.terminate(3, "File " + col + " should have .col extension!");
		}
		
		var f:FileInput = File.read(col);
		f.bigEndian = true;
		f.seek(0, FileSeek.SeekEnd);
		var fLength:Int = f.tell();
		
		f.seek(0x1F, FileSeek.SeekBegin);
		var shift:Int = f.readByte() + 1;
		
		palettes = new Array<Array<Int>>();
		
		while (f.tell() < fLength)
		{
			var pal:Array<Int> = new Array<Int>();
			var allSame:Bool = true;
			var lastCol:Int = 0;
			
			for (i in 0...16)
			{
				var col:Int = f.readInt32();
				var r:Int = ((col >>> 24) & 0xFF) << shift;
				var g:Int = ((col >>> 16) & 0xFF) << shift;
				var b:Int = ((col >>> 8) & 0xFF) << shift;
				var rgb:Int = (r << 16) + (g << 8) + b;
				
				pal.push(rgb);
				
				if (i != 0 && allSame == true && lastCol != rgb)
				{
					allSame = false;
				}
				
				lastCol = rgb;
			}
			
			if (!allSame) palettes.push(pal);
		}
		
		f.close();
	}
	
	static private function convertImage(csr:String, outDir:String)
	{
		Sys.println("Converting " + csr);
		
		if (Path.extension(csr) != "csr")
		{
			Sys.println("File should have " + csr + " should have .csr extension!");
			return;
		}
		
		var f:FileInput = File.read(csr);
		f.bigEndian = true;
		
		f.seek(0x20, FileSeek.SeekBegin);
		var w:Int = f.readUInt16();
		var h:Int = f.readUInt16();
		var byteNum:Int = Std.int(w * h / 2);
		
		f.seek(0x230, FileSeek.SeekBegin);
		var pixels:Array<Int> = new Array<Int>();
		
		for (i in 0...byteNum)
		{
			var b:Int = f.readByte();
			pixels.push((b >> 4) & 0x0F);
			pixels.push(b & 0x0F);
		}
		
		f.close();
		
		var csrNm:String = Path.withoutExtension(Path.withoutDirectory(csr));
		
		FileSystem.createDirectory(outDir + csrNm);
		
		for (i in 0...palettes.length)
		{
			var colPixels:BytesOutput = new BytesOutput();
			colPixels.bigEndian = true;
			
			for (j in 0...pixels.length)
			{
				colPixels.writeUInt24(palettes[i][pixels[j]]);
			}
			
			var d:Data = Tools.buildRGB(w, h, colPixels.getBytes());
			var fo:FileOutput = File.write(outDir + csrNm + "/" + csrNm + "_pal" + i + ".png");
			new Writer(fo).write(d);
			fo.close();
		}
	}
}