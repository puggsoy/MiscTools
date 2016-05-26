package;

import flash.display.Sprite;
import flash.display.Bitmap;
import flash.geom.Rectangle;
import flash.display.BitmapData;
import flash.geom.Point;
import openfl.Assets;
import Tile;
import GameUtils;

class IsoMap extends Sprite {
	
        public var name : String;
        public var mapWidth : Int;
        public var mapHeight : Int;
		
        public function new(fn:String) {

			var mapFile = Assets.getText("assets/" + fn + ".txt");
			var mapParts = mapFile.split(":");
			var mapHeader = mapParts[0];
			var mapData = mapParts[1];

			name = mapHeader.split(",")[0];
			mapWidth = Std.parseInt(mapHeader.split(",")[1]);
			mapHeight = Std.parseInt(mapHeader.split(",")[2]);

			var mapTiles = mapData.split(",");

			var my = 0;
			while (my < mapHeight) {
			var mx = 0;
				while (mx < mapWidth) {
					var mapPoint = new Point(mx, my);
					var mapOffset = new Point(GameUtils.SCREEN_WIDTH_HALF - Tile.TILE_WIDTH_HALF, 0);
					var tileNumber = Std.parseInt(mapTiles[mapWidth * my + mx]) - 1;
					var tile = new Tile(bitmapData, tileNumber, mapPoint, GameUtils.map_to_screen(mapPoint, mapOffset));
					addChild(tile);
					mx++;
				}
				my++;
			}
        }
    }