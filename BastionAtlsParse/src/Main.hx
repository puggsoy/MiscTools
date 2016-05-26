package;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Path;
import lime.utils.ByteArray;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

class Main 
{
	private var maps:Vector<AtlasMap>;
	
	public function new()
	{
		Begin.init();
		Begin.usage = 'Usage: BastionAtlsParse inFile\n    inFile: The ATLS to parse. Can also be a folder containing all the ATLS files to parse. The corresponding PNG(s) should be in the same folder\n';
		Begin.functions = [null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		if (!FileSystem.exists(Begin.args[0]))
		{
			End.terminate(1, 'inFile must exist!');
		}
		
		if (FileSystem.isDirectory(Begin.args[0]))
		{
			var files:Array<String> = FileSystem.readDirectory(Begin.args[0]);
			
			for (file in files)
			{
				if (Path.extension(file) == 'atls')
				{
					parseAtls(Begin.args[0] + '/' + file);
				}
			}
		}
		else
		{
			parseAtls(Begin.args[0]);
		}
		
		End.terminate(0, 'Done');
	}
	
	private function parseAtls(atlsPath:String)
	{
		var f:FileInput = File.read(atlsPath);
		f.bigEndian = false;
		
		if (f.readString(4) != 'ATLS')
		{
			Sys.println('Invalid ATLS file!');
			return;
		}
		
		var mapNum:Int = f.readInt32();
		maps = new Vector<AtlasMap>(mapNum);
		
		for (i in 0...mapNum)
		{
			maps[i] = new AtlasMap(f);
		}
		
		var len:Int = f.readByte();
		var xnbName:String = f.readString(len);
		len = f.readByte();
		var xnbPath:String = f.readString(len);
		var xnbSize:Int = f.readInt32();
		f.close();
		
		var dir:String = Path.directory(atlsPath);
		dir = (dir != '') ? Path.addTrailingSlash(dir) : '';
		var pngPath:String = '$dir$xnbName.png';
		
		if (!FileSystem.exists(pngPath))
		{
			Sys.println('$pngPath must exist!');
			return;
		}
		
		loadPNG(pngPath);
	}
	
	private function loadPNG(pngPath:String)
	{
		Sys.println('Loading $pngPath');
		var ba:ByteArray = ByteArray.readFile(pngPath);
		var pngDat:BitmapData = BitmapData.fromBytes(ba, null, extractAtlasMaps);
	}
	
	private function extractAtlasMaps(pngDat:BitmapData)
	{
		Sys.println('Done loading');
		
		for (map in maps)
		{
			var frame:BitmapData = new BitmapData(map.originalWidth, map.originalHeight, true, 0);
			var rect:Rectangle = new Rectangle(map.frameX, map.frameY, map.frameWidth, map.frameHeight);
			frame.copyPixels(pngDat, rect, new Point(map.animX, map.animY));
			
			var outPath:String = '${map.mapName}.png';
			var outDir:String = Path.directory(outPath);
			
			FileSystem.createDirectory(outDir);
			
			savePNG(frame, outPath);
			Sys.println(outPath);
		}
	}
	
	private function savePNG(bmp:BitmapData, filePath:String)
	{
		var dat:Data = Tools.build32ARGB(bmp.width, bmp.height, bmp.getPixels(bmp.rect));
		var o:FileOutput = File.write(filePath);
		new Writer(o).write(dat);
		o.close();
	}
	
	static function main() 
	{
		new Main();
	}
}