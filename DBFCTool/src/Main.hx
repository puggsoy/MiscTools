package;

import easyconsole.Begin;
import easyconsole.End;
import format.gz.Data.Header;
import format.gz.Reader;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

class Main 
{
	static function main() 
	{
		Begin.init();
		Begin.usage = "Usage: DBFCTool inDir pal outDir\n    inDir: A folder containing the .dds.gz files to convert\n    pal: The .pal file to use for the palette\n    outDir: The folder to save the converted files to";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	static private function checkArgs()
	{
		var inDir:String = Begin.args[0];
		
		if (!FileSystem.exists(inDir))
		{
			End.terminate(1, "inDir must exist!");
		}
		
		if (FileSystem.exists(inDir) && !FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "inDir must be a directory!");
		}
		
		inDir = Path.addTrailingSlash(inDir);
		
		var palFile:String = Begin.args[1];
		
		if (!FileSystem.exists(palFile))
		{
			End.terminate(1, "pal must exist!");
		}
		
		var outDir:String = Begin.args[2];
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(1, "outDir must be a directory!");
		}
		
		outDir = Path.addTrailingSlash(outDir);
		
		var pal:Vector<Int> = readPAL(palFile);
		
		var files:Array<String> = FileSystem.readDirectory(inDir);
		
		for (file in files)
		{
			if (file.substr( -7, 7) == ".dds.gz")
			{
				readDDS(Path.join([inDir, file]), pal, outDir);
			}
		}
		
		End.terminate(0, "Done");
	}
	
	static private function readInstructions(path:String)
	{
		var bytesIn:BytesInput = new BytesInput(File.getBytes(path));
		bytesIn.bigEndian = true;
		bytesIn.position = 0x4F24;
		var boff:Int = bytesIn.readInt32();
		bytesIn.position += 8;
		
		var num:Int = 0;
		
		for (i in 0...20)
		{
			bytesIn.position += 0x44;
			num += bytesIn.readInt16();
			bytesIn.position += 2;
		}
		
		trace(num);
	}
	
	static private function readPAL(path:String):Vector<Int>
	{
		var bytes:Bytes = File.getBytes(path);
		
		var ret:Vector<Int> = new Vector<Int>(0x100);
		
		var pos:Int = 0x4;
		for (i in 0...0x100)
		{
			var r:Int = bytes.get(pos);
			var g:Int = bytes.get(pos + 1);
			var b:Int = bytes.get(pos + 2);
			var a:Int = bytes.get(pos + 3);
			
			if (a > 0) a = 0xFF;
			
			var argb:Int = (a << 24) + (r << 16) + (g << 8) + b;
			ret[i] = argb;
			
			pos += 4;
		}
		
		return ret;
	}
	
	static private function readDDS(path:String, pal:Vector<Int>, outDir:String)
	{
		Sys.println('Converting $path');
		
		var f:FileInput = File.read(path);
		var r:Reader = new Reader(f);
		var outName:String = r.readHeader().fileName;
		var decomp:BytesOutput = new BytesOutput();
		r.readData(decomp);
		f.close();
		
		var inBytes:BytesInput = new BytesInput(decomp.getBytes());
		inBytes.position = 0x0C;
		var height:Int = inBytes.readInt32();
		var width:Int = inBytes.readInt32();
		var pixNum:Int = width * height;
		
		var outBytes:BytesOutput = new BytesOutput();
		outBytes.bigEndian = true;
		
		inBytes.position = 0x80;
		
		for (i in 0...pixNum)
		{
			outBytes.writeInt32(pal[inBytes.readByte()]);
		}
		
		var fname:String = Path.withoutExtension(Path.withoutExtension(Path.withoutDirectory(path)));
		var outPath:String = Path.join([outDir, '$fname.png']);
		
		savePNG(outPath, outBytes.getBytes(), width, height);
	}
	
	static private function savePNG(path:String, bytes:Bytes, width:Int, height:Int)
	{
		FileSystem.createDirectory(Path.directory(path));
		
		var f:FileOutput = File.write(path);
		var w:Writer = new Writer(f);
		var dat:Data = Tools.build32ARGB(width, height, bytes);
		w.write(dat);
		f.close();
	}
}