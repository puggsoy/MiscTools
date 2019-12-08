package ;

import haxe.macro.Expr.Catch;
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
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	private var inDir:String;
	private var palDir:String;
	private var outDir:String;
	private var palf:FileInput;
	private var hpls:Array<HPL>;
	
	public function new() 
	{
		Begin.init();
		Begin.usage = "Usage: hip2png inDir outDir\n    inDir: A folder containing the .hip files to convert\n    palDir: A folder containing the .hpl files to use\n    outDir: The folder to save the converted files to";
		Begin.functions = [null, null, null, checkArgs];
		
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		
		inDir = Begin.args[0];
		
		if (!FileSystem.exists(inDir))
		{
			End.terminate(1, "inDir must exist!");
		}
		else if (!FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "inDir must be a directory!");
		}
		
		inDir = Path.addTrailingSlash(inDir);
		
		palDir = Begin.args[1];
		
		if (!FileSystem.exists(palDir))
		{
			End.terminate(1, "palDir must exist!");
		}
		else if (!FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "palDir must be a directory!");
		}
		
		palDir = Path.addTrailingSlash(palDir);
		
		outDir = Begin.args[2];
		outDir = Path.addTrailingSlash(outDir);
		
		var palFiles:Array<String> = FileSystem.readDirectory(palDir);
		hpls = new Array<HPL>();
		
		for (file in palFiles)
		{
			if (Path.extension(file) == "hpl")
			{
				var path:String = Path.join([palDir, file]);
				hpls.push(loadPalette(path));
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
	
	private function loadPalette(filePath:String):HPL
	{
		if (filePath == null)
		{
			End.terminate(2, "Could not locate palette file!");
		}
		
		Sys.println('Loading palette $filePath');

		var name = Path.withoutExtension(Path.withoutDirectory(filePath));
		
		var f:FileInput = File.read(filePath);
		
		var hpl:HPL = null;

		try
		{
			hpl = new HPL(f, name);
		}
		catch (e:String)
		{
			f.close();
			End.terminate(3, e);
		}

		f.close();
		
		return hpl;
	}
	
	private function convertHIP(path:String)
	{
		Sys.println('Converting $path');
		
		// Load HIP
		var f:FileInput = File.read(path);
		
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
		
		for (i in 0...(hpls.length + 1))
		{
			var folderName:String = "";
			
			if (i == 0)
				folderName = "internal";
			else
				folderName = hpls[i - 1].name;
			
			var finalOutDir:String = Path.join([outDir, folderName]);
			FileSystem.createDirectory(finalOutDir);
			
			var filename:String = new Path(path).file;
			var outPath:String = Path.join([finalOutDir, Path.withExtension(filename, "png")]);
			
			var out:BytesOutput = null;
			if (i == 0)
				out = hip.getOutput(hip.internalPal);
			else
				out = hip.getOutput(hpls[i - 1].paletteData);
			
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