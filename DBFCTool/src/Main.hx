package;

import easyconsole.Begin;
import easyconsole.End;
import format.gz.Reader;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import openfl.display.BitmapData;
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
	public function new() 
	{
		Begin.init();
		Begin.usage = "Usage: DBFCTool inFile outDir\n    inFile: The .pac file to extract. Can alternatively be a folder of .pac files\n    outDir: The folder to save the converted files to";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		var inFile:String = Begin.args[0];
		
		if (!FileSystem.exists(inFile))
		{
			End.terminate(1, "inFile must exist!");
		}
		
		var outDir:String = Begin.args[1];
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(1, "outDir must be a directory!");
		}
		
		outDir = Path.addTrailingSlash(outDir);
		
		if (FileSystem.isDirectory(inFile)) 
		{
			var files:Array<String> = FileSystem.readDirectory(inFile);
			
			for (file in files)
			{
				if (Path.extension(file).toLowerCase() == 'pac')
				{
					readPAC(Path.join([inFile, file]), outDir);
				}
			}
		}
		else
		{
			readPAC(inFile, outDir);
		}
		
		End.terminate(0, "Done");
	}
	
	private function readPAC(path:String, outDir:String)
	{
		var f:FileInput = File.read(path);
		f.bigEndian = true;
		
		var magic1 = f.readInt32();
		var magic2 = f.readInt32();
		
		if (magic1 != 0x554B4172 || magic2 != 0x63000000)
		{
			End.terminate(1, 'Invalid PAC!');
		}
		
		f.readInt32(); //unknown
		var fileNum:Int = f.readInt32();
		
		var images:Map<String, Bytes> = null;
		var imgConstructs:Vector<ImgConstruct> = null;
		var pal:Vector<Int> = null;
		
		for (i in 0...fileNum)
		{
			var name:String = f.readString(0x40).split(String.fromCharCode(0))[0];
			var length:Int = f.readInt32();
			f.readInt32(); //unknown
			var offset:Int = f.readInt32() + 0x10;
			
			var ext:String = Path.extension(name).toLowerCase();
			
			var func:Bytes -> Void;
			
			switch(ext)
			{
				case 'cg':
					func = function(b){ imgConstructs = readCG(b); }
				case 'pal':
					func = function(b){ pal = readPAL(b); }
				case 'uka':
					func = function(b){ images = readCgarcUKA(b); }
				default:
					continue;
			}
			
			var o:Int = f.tell();
			f.seek(offset, FileSeek.SeekBegin);
			var bytes:Bytes = f.read(length);
			f.seek(o, FileSeek.SeekBegin);
			
			func(bytes);
		}
		
		if (imgConstructs == null) End.terminate(1, 'No .cg!');
		if (pal == null) End.terminate(1, 'No .pal!');
		if (images == null) End.terminate(1, 'No .uka!');
		
		for (c in imgConstructs)
		{
			var source:BitmapData = readDDS(images[c.imgName], pal);
			var outDat:BitmapData = constructSprite(source, c);
			
			savePNG(Path.join([outDir, Path.withoutExtension(Path.withoutDirectory(path)), Path.withExtension(c.imgName, 'png')]), outDat);
		}
		
		f.close();
	}
	
	private function readCgarcUKA(bytes:Bytes):Map<String, Bytes>
	{
		var b:BytesInput = new BytesInput(bytes);
		b.bigEndian = true;
		b.position = 0xC;
		var fileNum:Int = b.readInt32();
		
		var ret:Map<String, Bytes> = new Map<String, Bytes>();
		
		for (i in 0...fileNum)
		{
			var name:String = b.readString(0x40).split(String.fromCharCode(0))[0];
			var length:Int = b.readInt32();
			b.readInt32(); //unknown
			var offset:Int = b.readInt32() + 0x10;
			
			if (Path.extension(name).toLowerCase() != 'gz') continue;
			
			var o:Int = b.position;
			b.position = offset;
			var bytes:Bytes = b.read(length);
			b.position = o;
			
			var bi:BytesInput = new BytesInput(bytes);
			var r:Reader = new Reader(bi);
			var bo:BytesOutput = new BytesOutput();
			
			ret.set(Path.withoutExtension(name), r.read().data);
			
			bo.close();
			bi.close();
		}
		
		b.close();
		
		return ret;
	}
	
	private function readCG(bytes:Bytes):Vector<ImgConstruct>
	{
		var b:BytesInput = new BytesInput(bytes);
		b.bigEndian = true;
		
		b.position = 0x4F24;
		var startOff:Int = b.readInt32();
		b.readInt32(); //unknown, always 0?
		var endOff:Int = b.readInt32();
		var instructLen:Int = 0x18;
		
		b.position = 0x2020;
		var imgNum:Int = b.readInt32();
		b.position += 0x20;
		
		var ret:Vector<ImgConstruct> = new Vector<ImgConstruct>(imgNum);
		
		for (i in 0...imgNum)
		{
			var o:Int = b.position + 4;
			b.position = b.readInt32();
			
			var c:ImgConstruct =
			{
				imgName: b.readString(0x24).split(String.fromCharCode(0))[0],
				width: b.readInt32(),
				height: b.readInt32(),
				unks: b.read(0x16),
				instructOff: b.readInt16(),
				instructNum: b.readInt16(),
				instructs: null,
				unk0: b.readInt16()
			}
			
			c.instructs = new Vector<Instruction>(c.instructNum);
			b.position = startOff + (c.instructOff * instructLen);
			
			for (j in 0...c.instructNum)
			{
				var instruct:Instruction =
				{
					newX: b.readInt32(),
					newY: b.readInt32(),
					w: b.readInt32(),
					h: b.readInt32(),
					x: b.readInt16(),
					y: b.readInt16(),
					imgNum: b.readInt16(),
					unk: b.readInt16()
				}
				
				c.instructs[j] = instruct;
			}
			
			ret[i] = c;
			
			b.position = o;
		}
		
		return ret;
	}
	
	private function readPAL(bytes:Bytes):Vector<Int>
	{
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
	
	private function readDDS(bytes:Bytes, pal:Vector<Int>):BitmapData
	{
		var inBytes:BytesInput = new BytesInput(bytes);
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
		
		var bmp:BitmapData = new BitmapData(width, height, true, 0);
		bmp.setPixels(bmp.rect, ByteArray.fromBytes(outBytes.getBytes()));
		
		//var fname:String = Path.withoutExtension(Path.withoutExtension(Path.withoutDirectory(path)));
		//var outPath:String = Path.join([outDir, '$fname.png']);
		
		//savePNG(outPath, outBytes.getBytes(), width, height);
		return bmp;
	}
	
	private function constructSprite(source:BitmapData, imgConstruct:ImgConstruct):BitmapData
	{
		var ret:BitmapData = new BitmapData(imgConstruct.width, imgConstruct.height, true, 0);
		
		for (i in imgConstruct.instructs)
		{
			ret.copyPixels(source, new Rectangle(i.x, i.y, i.w, i.h), new Point(i.newX, i.newY));
		}
		
		return ret;
	}
	
	static public function savePNG(path:String, bmp:BitmapData)
	{
		Sys.println('Saving $path...');
		
		if(Path.directory(path) != '') FileSystem.createDirectory(Path.directory(path));
		
		var dat:Data = Tools.build32ARGB(bmp.width, bmp.height, Bytes.ofData(bmp.getPixels(bmp.rect)));
		var o:FileOutput = File.write(path);
		new Writer(o).write(dat);
		o.close();
	}
	
	static function main()
	{
		new Main();
	}
}

typedef ImgConstruct =
{
	imgName:String,
	width:Int,
	height:Int,
	unks:Bytes,
	instructOff:Int,
	instructNum:Int,
	instructs:Vector<Instruction>,
	unk0:Int //always 0?
}

typedef Instruction =
{
	newX:Int,
	newY:Int,
	w:Int,
	h:Int,
	x:Int,
	y:Int,
	imgNum:Int,
	unk:Int //always 0, apparently
}