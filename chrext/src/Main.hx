package;

import easyconsole.Begin;
import easyconsole.End;
import haxe.io.Path;
import lime.graphics.Image;
import lime.math.Rectangle;
import lime.math.Vector2;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	public function new()
	{
		Begin.init();
		Begin.usage = "Usage: chrext inFile outDir\n    inFile: The .chr file to extract. Can alternatively be a folder containing the files to extract\n    outDir: The folder to put the subfolders where the frames will be extracted to";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	/**
	 * Checks the give arguments and parses them
	 */
	private function checkArgs():Void
	{
		var inFile:String = Begin.args[0];
		var outDir:String = Begin.args[1];
		
		//Check file or folder
		if (!FileSystem.exists(inFile))
			End.terminate(1, 'inFile must be a valid file/directory!');
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
			End.terminate(2, 'outDir must be a valid directory!');
		
		if (FileSystem.isDirectory(inFile))
		{
			var files:Array<String> = FileSystem.readDirectory(inFile);
			
			for (f in files)
			{
				if (Path.extension(f).toLowerCase() == 'chr')
				{
					extractCHR('$inFile/$f', Path.join([outDir, Path.withoutExtension(f)]));
				}
			}
		}
		else
		{
			extractCHR(inFile, Path.join([outDir, new Path(inFile).file]));
		}
		
		End.anyKeyExit(0, 'Done');
	}
	
	/**
	 * Extracts the frames from the CHR
	 * @param	inFile	Input file paths
	 * @param	outDir	Output directory for subfolders
	 */
	private function extractCHR(inFile:String, outDir:String):Void
	{
		Sys.println('Extracting $inFile');
		
		var f:FileInput = File.read(inFile);
		f.bigEndian = false;
		var valShorts:Bool = true; //frame values are shorts or bytes
		
		//Checking magic ID
		if (f.readString(2) != 'V2')
		{
			Sys.println("No magic ID?");
			f.seek( -2, FileSeek.SeekCur);
			valShorts = false;
		}
		
		var frameOff:UInt = f.readUInt16(); //frame info offset
		var unkOff:UInt = f.readUInt16(); //offset for the stuff after frames (alignment/animations?)
		var pngOff:UInt = f.readInt32(); //png offset
		
		//Read in the PNG
		f.seek(pngOff, FileSeek.SeekBegin);
		var len:UInt = f.readUInt16();
		var img:Image = Image.fromBytes(f.read(len));
		
		//Go to frame info
		f.seek(frameOff, FileSeek.SeekBegin);
		len = f.readByte();
		
		var count:Int = 1;
		for (i in 0...len)
		{
			var x:UInt = valShorts ? f.readUInt16() : f.readByte();
			var y:UInt = valShorts ? f.readUInt16() : f.readByte();
			var w:UInt = valShorts ? f.readUInt16() : f.readByte();
			var h:UInt = valShorts ? f.readUInt16() : f.readByte();
			
			if (w == 0 || h == 0) continue;
			
			var frame:Image = new Image(null, 0, 0, w, h, 0);
			frame.copyPixels(img, new Rectangle(x, y, w, h), new Vector2(0, 0));
			
			savePNG(new Path(inFile).file + '_$count', outDir, frame);
			count++;
		}
		
		f.close();
	}
	
	private function savePNG(fname:String, outDir:String, img:Image):Void
	{
		FileSystem.createDirectory(outDir);
		var outPath:String = Path.join([outDir, fname + ".png"]);
		
		Sys.println("Saving " + outPath);
		
		var w:FileOutput = File.write(outPath);
		w.write(img.encode('png'));
		w.close();
	}
	
	static function main():Void
	{
		new Main();
	}
}