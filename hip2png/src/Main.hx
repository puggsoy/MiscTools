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
import neko.Lib;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	private var f:FileInput;
	private var inDir:String;
	private var palDir:String;
	private var outDir:String;
	private var palf:FileInput;
	private var palettes:Array<Vector<Int>>;
	private var paletteNames:Array<String>;
	
	public function new() 
	{
		Begin.init();
		Begin.usage = "Usage: hip2png inDir outDir [-p]\n    inDir: A folder containing the .hip files to convert\n    palDir: A folder containing the .hpl files to use\n    outDir: The folder to save the converted files to";
		Begin.functions = [null, null, null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		
		inDir = Begin.args[0];
		
		if (FileSystem.exists(inDir) && !FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "inDir must be a directory!");
		}
		
		inDir = Path.addTrailingSlash(inDir);
		
		palDir = Begin.args[1];
		
		if (FileSystem.exists(inDir) && !FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "palDir must be a directory!");
		}
		
		palDir = Path.addTrailingSlash(palDir);
		
		outDir = Begin.args[2];
		outDir = Path.addTrailingSlash(outDir);
		
		var palFiles:Array<String> = FileSystem.readDirectory(palDir);
		palettes = new Array<Vector<Int>>();
		paletteNames = new Array<String>();
		
		for (file in palFiles)
		{
			if (Path.extension(file) == "hpl")
			{
				palettes.push(loadPalette(Path.join([palDir, file])));
				paletteNames.push(Path.withoutExtension(file));
			}
		}
		
		var files:Array<String> = FileSystem.readDirectory(inDir);
		
		for (file in files)
		{
			if (Path.extension(file) == "hip")
			{
				convertHIP(Path.join([inDir, file]));
			}
		}
		
		End.terminate(0, "Done");
	}
	
	private function loadPalette(filePath:String):Vector<Int>
	{
		if (filePath == null)
		{
			End.terminate(2, "Could not locate palette file!");
		}
		
		Sys.println('Loading palette $filePath');
		
		var palf:FileInput = File.read(filePath);
		palf.bigEndian = true;
		
		if (palf.readString(4) != "HPAL")
		{
			palf.close();
			End.terminate(2, "Invalid HPL file!");
		}
		
		palf.seek(0x20, FileSeek.SeekBegin);
		
		var palette:Vector<Int> = new Vector<Int>(0x100);
		
		for (i in 0...palette.length)
		{
			var argb:Int = palf.readInt32();
			palette[i] = argb;
		}
		
		palf.close();
		
		return palette;
	}
	
	private function convertHIP(path:String)
	{
		Sys.println('Converting $path');
		
		// Load HIP
		f = File.read(path);
		
		var hip:HIP = null;
		
		try
		{
			hip = new HIP(f);
		}
		catch (e:String)
		{
			f.close();
			End.terminate(3, e);
		}
		
		f.close();
		
		for (i in 0...(palettes.length + 1))
		{
			var folderName:String = "";
			
			if (i == 0)
				folderName = "internal";
			else
				folderName = paletteNames[i - 1];
			
			var finalOutDir:String = Path.join([outDir, folderName]);
			FileSystem.createDirectory(finalOutDir);
			
			var filename:String = new Path(path).file;
			var outPath:String = Path.join([finalOutDir, Path.withExtension(filename, "png")]);
			
			var out:BytesOutput = null;
			if (i == 0)
				out = hip.getOutput(hip.internalPal);
			else
				out = hip.getOutput(palettes[i - 1]);
			
			savePNG(out.getBytes(), hip.getWidth(), hip.getHeight(), outPath);
		}
	}
	
	private function savePNG(bytes:Bytes, width:Int, height:Int, outPath:String)
	{
		try
		{
			var pngDat:Data = Tools.build32ARGB(width, height, bytes);
			var fout:FileOutput = File.write(outPath);
			var w:Writer = new Writer(fout);
			Sys.println("Saving " + outPath);
			w.write(pngDat);
			fout.close();
		}
		catch (e:Dynamic)
		{
			trace('Error: $e');
		}
	}
	
	static function main()
	{
		new Main();
	}
}