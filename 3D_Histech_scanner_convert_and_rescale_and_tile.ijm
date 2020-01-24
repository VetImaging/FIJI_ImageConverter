/* Macro for converting 
 * extended tifs from Histech3D-slidescanner (vetmeduni-pathology), jpg, png, tif
 * optional resizing and tiling if the images
 * input: jpg, png, tif
 * output: jpg, png, tif
 * SK / VetImaging / VetCore / Vetmeduni Vienna 2020
 */

/* Create interactive Window to set variables for 
 * input/output folder, input/output suffix, scale factor, subfolder-processing
 */
#@ String (visibility=MESSAGE, value="Choose your files and parameter", required=false) msg
#@ File (label = "Input directory", style = "directory") 		input_folder
#@ File (label = "Output directory", style = "directory") 		output_folder
#@ String (label = "File suffix input", choices={".jpg",".png",".tif",".jpeg",".tiff"}, style="radioButtonHorizontal") 	suffix_in
#@ String (label = "File suffix output", choices={".jpg",".png",".tif"}, style="radioButtonHorizontal") 	suffix_out
#@ Integer (label = "Scale factor (%)", value=100) 			scale_percentage
#@ String (label = "Tile image", choices={"1", "2x2","3x3","4x4"}, style="radioButtonHorizontal") 	image_tiles
#@ String (label = "Include subfolders", choices={"no","yes"}, style="radioButtonHorizontal") 		subfolders
#@ String (label = "Run in silent batch mode", choices={"no","yes"}, style="radioButtonHorizontal") 	runBatch

run("Collect Garbage");

if(runBatch=="yes"){ setBatchMode(true); }

processFolder(input_folder);


// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input_folder) {
	filelist = getFileList(input_folder);
	filelist = Array.sort(filelist);
	for (i = 0; i < filelist.length; i++) {
		
		// process recursion for subfolders if option "Include subfolders" is true
		if(subfolders=="yes"){
		if(File.isDirectory(input_folder + File.separator + filelist[i]))
			processFolder(input_folder + File.separator + filelist[i]);}
			
		// for images with correct suffix proceed with function processFile()
		if(endsWith(filelist[i], suffix_in))
			processFile(input_folder, output_folder, filelist[i]);
		
		run("Close All");
		run("Collect Garbage");
	}
}

// function to open file, convert to RGB, rescale and save as defined in "suffix_out"
function processFile(input_folder, output_folder, file) {

	if(suffix_in==".tif"||suffix_in==".tiff"){
    	run("Bio-Formats Windowless Importer", "open=[" + input_folder + "\\" + file +"]");
    	run("RGB Color");
	}

	if(suffix_in==".jpg"||suffix_in==".jpeg"||suffix_in==".png"){
    	open(input_folder + "\\" + file);
	}
	id = getImageID();
	scale_factor=scale_percentage/100;
	scaled_width=round(scale_factor * getWidth());
	scaled_height=round(scale_factor * getHeight());
	run("Scale...", "x=" + scale_factor + " y="+ scale_factor +" width="+ scaled_width +" height=" + scaled_height +" interpolation=Bilinear average create");
	
	// export of ROIs with Case Converter adds "_Default_Extended" to the filename
	if (endsWith(getTitle(),"_Default_Extended.tif (RGB)-1")) 
		file = replace(file, "_Default_Extended.tif", "");
	
	// export of Whole slides with Case Converter adds "_Wholeslide_Default_Extended" to the filename
	if (endsWith(getTitle(),"_Wholeslide_Default_Extended.tif (RGB)-1")) 
		file = replace(file, "_Wholeslide_Default_Extended.tif", "");
	
	if (endsWith(getTitle(),".mrxs")) 
		file = replace(file, ".mrxs", "");

	if (image_tiles!="1") tile_image(id);
	else {		
	if(suffix_out==".jpg") 
		saveAs("Jpeg", output_folder + "\\" + file + ".jpg");

	if(suffix_out==".png") 
		saveAs("PNG", output_folder + "\\" + file + ".png");
		
	if(suffix_out==".tif") 
		saveAs("Tiff", output_folder  + "\\" + file + ".tif");
	}
}

// FIJI created macro for color-threshold, excluding white pixels (0-254)
function colorthreshold(file){
	roiManager("reset");
	min=newArray(3);
	max=newArray(3);
	filter=newArray(3);
	a=getTitle();
	run("RGB Stack");
	run("Convert Stack to Images");
	selectWindow("Red");	rename("0");
	selectWindow("Green");	rename("1");
	selectWindow("Blue");	rename("2");
	min[0]=0;	max[0]=254;	filter[0]="pass";
	min[1]=0;	max[1]=254;	filter[1]="pass";
	min[2]=0;	max[2]=254;	filter[2]="pass";
	
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  setThreshold(min[i], max[i]);
	  run("Convert to Mask");
	  if (filter[i]=="stop")  run("Invert");
	}
	imageCalculator("AND create", "0","1");
	imageCalculator("AND create", "Result of 0","2");
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  run("Close");
	}
	selectWindow("Result of 0");		run("Close");
	selectWindow("Result of Result of 0");	rename(a);
}


function tile_image(tile_file){
	if (image_tiles=="2x2") n=2; 
	if (image_tiles=="3x3") n=3; 
	if (image_tiles=="4x4") n=4;
	id = getImageID();
	title = getTitle();
	// export of ROIs with Case Converter adds "_Default_Extended" to the filename
		if (endsWith(getTitle(),"_Default_Extended.tif (RGB)-1")) 
		title = replace(title, "_Default_Extended.tif", "");
	
	// export of Whole slides with Case Converter adds "_Wholeslide_Default_Extended" to the filename
		if (endsWith(getTitle(),"_Wholeslide_Default_Extended.tif (RGB)-1")) 
		title = replace(title, "_Wholeslide_Default_Extended.tif", "");
	
	getLocationAndSize(locX, locY, sizeW, sizeH);
	width = getWidth();
	height = getHeight();
	tileWidth = width / n;
	tileHeight = height / n;
	for (y = 0; y < n; y++) {
	offsetY = y * height / n;
 		for (x = 0; x < n; x++) {
			offsetX = x * width / n;
			selectImage(id);
			run("Duplicate...", "title=" + " [" + x + "," + y + "]"); 
			makeRectangle(offsetX, offsetY, tileWidth, tileHeight);
 			run("Crop");
			tile_file = title + " [" + x + "," + y + "]";

	if(suffix_out==".jpg") 
		saveAs("Jpeg", output_folder + "\\" + tile_file + ".jpg");

	if(suffix_out==".png") 
		saveAs("PNG", output_folder + "\\" + tile_file + ".png");
		
	if(suffix_out==".tif") 
		saveAs("Tiff", output_folder  + "\\" + tile_file + ".tif");

	close();
		}
	}
selectImage(id); 
close();
}