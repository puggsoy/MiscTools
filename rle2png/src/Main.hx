package ;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class Main 
{
	private var outDir:String;
	
	public function new()
	{
		Begin.init();
		Begin.usage = "Usage: rle2png inFile outDir\n    inFile: The .rle file to convert. Can alternatively be a folder containing the files to convert\n    outDir: The folder to save the converted files to";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		outDir = Begin.args[1];
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(1, "outDir must be a directory!");
		}
		
		if (FileSystem.isDirectory(Begin.args[0]))
		{
			var files:Array<String> = FileSystem.readDirectory(Begin.args[0]);
			
			for (file in files)
			{
				if (Path.extension(file).toLowerCase() == "rle")
				{
					loadFile(Begin.args[0] + "/" + file);
				}
			}
		}
		else
		{
			loadFile(Begin.args[0]);
		}
		
		End.terminate(0, "Done");
	}
	
	private function loadFile(path:String)
	{
		Sys.println("Converting " + path);
		var f:FileInput = File.read(path);
		f.bigEndian = false;
		
		//Header
		var width:UInt = f.readInt32();
		var height:UInt = f.readInt32();
		var length:UInt = f.readInt32();
		
		var palOff:UInt = 0xC;
		var palLen:UInt = 0x400;
		
		var tableOff:UInt = 0x40C;
		
		//Palette
		f.seek(palOff, FileSeek.SeekBegin);
		var palette:Vector<UInt> = new Vector<UInt>(0x100);
		
		for (i in 0...palette.length)
		{
			var b:UInt = f.readByte();
			var g:UInt = f.readByte();
			var r:UInt = f.readByte();
			var a:UInt = f.readByte();
			a = Std.int(Math.min(a * 2, 0xFF));
			
			var rgba:UInt = (r << 24) | (g << 16) | (b << 8) | a;
			
			if (i % 32 > 7 && i % 32 < 16) palette[i + 8] = rgba;
			else
			if (i % 32 > 15 && i % 32 < 24) palette[i - 8] = rgba;
			else palette[i] = rgba;
		}
		
		//RLE data
		f.seek(tableOff, FileSeek.SeekBegin);
		var frameNum:UInt = f.readInt32();
		var offsets:Vector<UInt> = new Vector<UInt>(frameNum);
		
		for (i in 0...frameNum)
		{
			offsets[i] = f.readInt32() + tableOff;
		}
		
		for (i in 0...offsets.length)
		{
			var off:UInt = offsets[i];
			var b:Bytes = extractFrame(f, off, palette, width);
			
			var fname:String = new Path(path).file + '_$i';
			savePNG(fname, b, width, width);
		}
	}
	
	private function extractFrame(f:FileInput, offset:UInt, palette:Vector<UInt>, width:UInt):Bytes
	{
		var pixels:Vector<UInt> = new Vector<UInt>(width * width);
		f.seek(0, FileSeek.SeekEnd);
		var fLen:UInt = f.tell();
		f.seek(offset, FileSeek.SeekBegin);
		
		var count:UInt = 0;
		while(f.tell() + 1 < fLen)
		{
			var num:UInt = f.readByte();
			if (num == 0) break;
			
			var pix:UInt = f.readByte();
			
			for (j in 0...num)
			{
				pixels[count++] = pix;
			}
		}
		
		var pixelsOut:BytesOutput = new BytesOutput();
		pixelsOut.bigEndian = true;
		
		for (val in pixels)
		{
			pixelsOut.writeInt32(palette[val]);
		}
		
		return pixelsOut.getBytes();
	}
	
	private function savePNG(fname:String, bytes:Bytes, w:UInt, h:UInt)
	{
		FileSystem.createDirectory(outDir);
		
		var outPath:String = Path.join([outDir, fname + ".png"]);
		
		var pngDat:Data = Tools.build32BGRA(w, h, bytes);
		var w:Writer = new Writer(File.write(outPath));
		Sys.println("Saving " + outPath);
		w.write(pngDat);
	}
	
	static function main()
	{
		new Main();
	}
}