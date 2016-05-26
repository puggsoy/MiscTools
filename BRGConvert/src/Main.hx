package ;

import console.End;
import format.png.Data;
import format.png.Writer;
import haxe.io.Output;
import haxe.io.Path;
import neko.Lib;
import console.Begin;
import sys.FileSystem;
import sys.io.File;
import systools.Dialogs;
import systools.Dialogs.FILEFILTERS;

class Main 
{
	static private inline var USAGE:String = "Command line usage: BRGConvert inDir outDir\n    inDir: Directory containing the files to convert\n    outDir: Directory where converted images will be saved";
	static private var outDirExists:Bool = true;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = USAGE;
		Begin.functions[0] = selectFiles;
		Begin.functions[2] = getPathsFromArgs;
		Begin.parseArgs();
	}
	
	static private function selectFiles(args:Array<String>)
	{
		Sys.println("Select the BRG files convert");
		
		var filter:FILEFILTERS = { count:1, descriptions:["BRG Files"], extensions:["*.brg"] };
		var files:Array<String> = Dialogs.openFile("Choose files", "Choose files", filter);
		
		if (files == null)
		{
			End.anyKeyExit(2, "No files selected!");
		}
		
		Sys.println("Select the folder to save the converted images");
		
		var outDir:String = Dialogs.folder("Choose folder", "Choose folder");
		
		if (outDir == null)
		{
			End.anyKeyExit(2, "No folder selected!");
		}
		
		extractImages(files, outDir);
	}
	
	static private function getPathsFromArgs(args:Array<String>)
	{
		if (FileSystem.exists(args[0]))
		{
			if (!FileSystem.isDirectory(args[0]))
			{
				End.anyKeyExit(3, "First argument is not a directory!");
			}
		}
		else
		{
			End.anyKeyExit(3, "First argument does not exist!");
		}
		
		var inFiles:Array<String> = new Array();
		recursiveDirectoryRead(args[0], inFiles, "BRG");
		
		if (FileSystem.exists(args[1]))
		{
			if (!FileSystem.isDirectory(args[1]))
			{
				End.anyKeyExit(3, "Second argument is not a directory!");
			}
		}
		else
		{
			outDirExists = false;
		}
		
		extractImages(inFiles, args[1]);
	}
	
	static private function recursiveDirectoryRead(path:String, array:Array<String>, ext:String)
	{
		var contents:Array<String> = FileSystem.readDirectory(path);
		
		for (file in contents)
		{
			if (Path.extension(file).toUpperCase() == ext.toUpperCase())
			{
				array.push(Path.removeTrailingSlashes(path) + "/" + file);
			}
			else
			if (FileSystem.isDirectory(path + "/" + file))
			{
				recursiveDirectoryRead((Path.removeTrailingSlashes(path) + "/" + file), array, ext);
			}
		}
	}
	
	static private function extractImages(inFiles:Array<String>, outDir:String)
	{
		for (file in inFiles)
		{
			var filePath:Path = new Path(file);
			var fileName:String = filePath.file + "." + filePath.ext;
			
			Sys.println("Converting " + fileName);
			var image:Data = BRG.convertFile(File.getBytes(file));
			
			if (image == null)
			{
				continue;
			}
			
			if (!outDirExists)
			{
				FileSystem.createDirectory(outDir);
			}
			
			var out:Output = File.write(outDir + "/" + filePath.file + ".png");
			var w:Writer = new Writer(out);
			w.write(image);
			out.close();
			
			Sys.println("Done");
		}
		
		End.anyKeyExit(0, "Complete");
	}
}