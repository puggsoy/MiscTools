package;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
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
	private var outDir:String = '.';
	
	private function new() 
	{
		Begin.init();
		Begin.usage = 'Usage: TextureUnPacker imgFile xmlFile outDir \n\nArguments:\n    imgFile: The image containing the sprites to be unpacked\n    xmlFile: The .xml file corresponding to the image to unpack\n    outDir: The folder where the output should be extracted to';
		Begin.functions = [null, null, null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		var args:Array<String> = Begin.args;
		
		var tmp:String;
		
		if (!FileSystem.exists(tmp = args[0]) || !FileSystem.exists(tmp = args[1]))
		{
			End.terminate(0, '$tmp doesn\'t exist!\n');
		}
		
		outDir = args[2];
		unPack(args[0], args[1]);
		
		End.terminate(0, 'All done!');
	}
	
	private function unPack(imgPath:String, xmlPath:String)
	{
		
		var img:BitmapData = BitmapData.fromFile(imgPath);
		
		var xml:Xml = Xml.parse(File.getContent(xmlPath));
		var textureAtlas:Xml = xml.firstElement();
		
		for (subTexture in textureAtlas.elementsNamed("SubTexture"))
		{
			var outName:String = subTexture.get('name');
			var x:Int = Std.parseInt(subTexture.get('x'));
			var y:Int = Std.parseInt(subTexture.get('y'));
			var w:Int = Std.parseInt(subTexture.get('width'));
			var h:Int = Std.parseInt(subTexture.get('height'));
			
			var spr:BitmapData = new BitmapData(w, h, true, 0);
			spr.copyPixels(img, new Rectangle(x, y, w, h), new Point(0, 0));
			savePNG(outName, spr);
		}
	}
	
	private function savePNG(name:String, bmp:BitmapData)
	{
		var outPath:String = Path.join([outDir, '$name.png']);
		FileSystem.createDirectory(Path.directory(outPath));
		
		var pngDat:Data = Tools.build32ARGB(bmp.width, bmp.height, bmp.getPixels(bmp.rect));
		var o:FileOutput = File.write(outPath);
		var w:Writer = new Writer(o);
		w.write(pngDat);
		o.close();
		
		Sys.println('$outPath saved!');
	}
	
	static function main() 
	{
		new Main();
	}
}