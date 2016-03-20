# ShapefileReader
__A shapefile reader in Swift__

__Description__

Reads data from files in [Shapefile](https://en.wikipedia.org/wiki/Shapefile) format.

__API Overview__

ShapefileReader is the only object you instantiate.

```swift
guard let sr = ShapefileReader(path: "g1g15.shp") else { assertionFailure() }

print("bbox: \(sr.shp.bbox)")
```

    bbox: (485410.978799999, 75286.5438000001, 833837.895, 295674.081300002)

Internally, it builds the three following objects, depending on the available auxiliary files:
- `SHPReader` to read the shapes, ie the list of points
- `DBFReader` to read the data records associated with the shapes
- `SHXReader` to read the indices of the shapes, thus allowing direct access

```swift
// if dbf file exists
if let dbf = sr.dbf {
    // number of records
    let n = dbf.numberOfRecords
    
    // iterate over records
    for r in dbf.recordGenerator() {
        // ...
    }
    
    // access a record by its index
    print(dbf.fields)
    let r = dbf[1847]
    print(r)
}
```

    [[DeletionFlag, C, 1, 0], [GMDNR, N, 9, 0], [GMDNAME, C, 50, 0], [BZNR, N, 9, 0], [KTNR, N, 9, 0], [GRNR, N, 9, 0], [AREA_HA, N, 9, 0], [X_MIN, N, 9, 0], [X_MAX, N, 9, 0], [Y_MIN, N, 9, 0], [Y_MAX, N, 9, 0], [X_CNTR, N, 9, 0], [Y_CNTR, N, 9, 0], [Z_MIN, N, 9, 0], [Z_MAX, N, 9, 0], [Z_AVG, N, 9, 0], [Z_MED, N, 9, 0], [Z_CNTR, N, 9, 0]]  
    [5586, Lausanne, 2225, 22, 1, 4138, 534438, 544978, 150655, 161554, 538200, 152400, 371, 930, 670, 666, 585]

```swift
// iterate over shapes
for (i,s) in sr.shp.shapeGenerator().enumerate() {
    print("[\(i)] \(s.shapeType), \(s.points.count) points, \(s.parts.count) part(s), bbox \(s.bbox)")
}
```

    [0] Polygon, 15 points, 1 part(s), bbox (678122.18, 234918.765000001, 681154.07, 238543.835000001)
    [1] Polygon, 19 points, 1 part(s), bbox (673824.878800001, 235223.84, 678569.727499999, 239338.513799999)
    [2] Polygon, 11 points, 1 part(s), bbox (675809.7588, 238997.66, 679006.858800001, 243159.239999998)

```swift
// if index file exists
if let shx = sr.shx {
    // access a shape by its index
    if let shape = sr[1847] {
        print(shape.shapeType)
        print(shape.points)
    }
}
```

    Polygon
    [(536987.156300001, 159265.289999999), (537952.996300001, 158971.131299999), (538014.390000001, 158915.75), ..., ]

```swift
// iterate over both shapes and records in the same time
for (s,r) in sr.shapeRecordGenerator() {
    //
}
```

__Implementation Details__

- points are CGPoint arrays
- direct access and enumerators are used each time it is possible
- the code will crash when it doesn't find the expected data

__Tests and Drawing__

The project comes with a unit test target.

Also, it comes with `BitmapCanvas` and its subclass `BitmapCanvasShapefile` which will generate the following PNG file.

You just need to change the path at the beginning of the `draw()` function in `main.swift` according the project's location.

<a href="img/switzerland.png"><img src="img/switzerland.png" width="890" alt="Switzerland Shapefile" /></a>
