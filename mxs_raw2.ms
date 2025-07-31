/* 	--------------- M A X S C R I P T ----------------- //
	Script:     Imports Model from RAW2
	Author:     Corey Nguyen
	Date:       2025-07-05
	
	2025-07-05
		Wrote it!
// 	-------------------------------------------------- */
gc()
clearListener()

try(DestroyDialog raw2)catch(raw2)
rollout raw2 "[XBOX] RAW2" (
	
	group "Import / Export" (
		button btn_import "Import FML" width:120 height:36 align:#center
		checkBox chk_clear "ClearScene" checked:false align:#center
	--	)
	--group "Save" (
		button btn_export "Export FML" width:120 height:36 align:#center
		button btn_unpack "Unpack FPK" width:120 height:18 align:#center
		--label lblmat1 "please use standardmaterial" align:#left
		--label lblmat2 "set specular to 12" align:#left
		)
	group "Manage Materials" (
		button btnLoad "Load" width:64 align:#center across:2
		button btnSave "Save" width:64 align:#center


		listbox lbMats "Materials" height:4 align:#center multiselect:true
		button btnAddMat "Add" width:45 align:#center across:3
		button btnDelMat "Delete" width:45 align:#center
		button btnAuto "Rename" width:45 align:#center
		button btnCopy "Copy" width:45 align:#center across:3
		button btnPaste "Paste" width:45 align:#center
		button btnUndo "Undo" width:45 align:#center
		editText edtName "Mat Name" text:"" 
		colorpicker cpAmb "Amb" fieldWidth:46 align:#right across:2
		colorpicker cpDif "Dif" fieldWidth:46 align:#right
		colorpicker cpSpe "Spe" fieldWidth:46 align:#right across:2
		colorpicker cpIll "Emi" fieldWidth:46 align:#right
		spinner spnSpecLvl "Spec Lvl" range:[0,255,25] type:#integer fieldWidth:76
		dropDownList ddlTex "Texture" items:#("-- none --") 
		button btnApply "Apply to Selected" width:140


		listbox lbTex "Textures" height:4 align:#center multiselect:false
		editText edtTexName "Texture Name" text:""
		editText edtFileName "File Name" text:""
		button btnAddTex "Add" width:45 align:#center across:3
		button btnDelTex "Delete" width:45 align:#center
		button btnApplyTex "Apply" width:45 align:#center



		listbox lbObjs "Objects" height:4 align:#center multiselect:false


		Multilistbox lbMeshes "Submeshes" height:4 align:#center multiselect:true
		button btnAssign "Assign to Selected"
		)


	
-- 	group "About" (
-- 		label lb3 "Written By:" align:#left
-- 		label lb4 "    mariokart64n" align:#left
-- 		hyperLink lb5 "    mariokart64n@gmail.com" address:"mailto:mariokart64n@gmail.com"
-- 		label lb6 "Donate:" align:#left across:2
-- 		hyperLink lb7 "    Paypal" address:"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=coreynguyen%40gmail%2ecom&item_name=maxscript%20work&no_shipping=0&no_note=1&tax=0&currency_code=CAD&lc=US&bn=PP%2dDonationsBF&charset=UTF%2d8"
-- 		)
	label lb3b "Release:" align:#left across:2
	label lb3c "July 30, 2025" align:#right
	
	struct FoolPackageDir_t (
		/*char[20]*/name = "",   -- null-terminated filename
		/*uint16*/ num_subdirs = 0,
		/*uint16*/ num_files = 0,
		/*uint32*/ subdir_ptr = 0, -- reserved for memory pointers
		/*uint32*/ file_ptr = 0,   -- reserved for memory pointers
		
		fn readFixedString f strlen = (
			local s = "", b = 1
			if strlen == undefined do format "Failed at %\n" (ftell f)
			for i = 1 to strlen do (
				b = readbyte f #unsigned
				if b == undefined do format "Failed at %\n" (ftell f)
				if b > 0 then (
					s += bit.IntAsChar b
					)
				else (
					fseek f (strlen - i) #seek_cur
					exit
					)
				)
			s
			),
		
		fn read f = (
			name = readFixedString f 20
			num_subdirs = readShort f #unsigned
			num_files = readShort f #unsigned
			subdir_ptr = readLong f #unsigned
			file_ptr = readLong f #unsigned
			)
		)
	
	struct FoolPackageFile_t (
		/*char[20]*/ name = "",   -- null-terminated filename
		/*uint32*/ offset = 0,     -- Offset to the file's data blob, relative to the start of the data block (after header + all entries)
		/*uint32*/ length = 0,     -- size of data
		
		fn readFixedString f strlen = (
			local s = "", b = 1
			if strlen == undefined do format "Failed at %\n" (ftell f)
			for i = 1 to strlen do (
				b = readbyte f #unsigned
				if b == undefined do format "Failed at %\n" (ftell f)
				if b > 0 then (
					s += bit.IntAsChar b
					)
				else (
					fseek f (strlen - i) #seek_cur
					exit
					)
				)
			s
			),
		
		fn read f = (
			name = readFixedString f 20
			offset = readLong f #unsigned
			length = readLong f #unsigned
			)
		)
	
	struct FoolPackageHeaderV2_t (
		/*uint32*/ flag4 = 0x20000000, -- 0x20000000 is Little Endian
		/*uint32*/ num_dirs = 0,
		/*uint32*/ num_files = 0,
		/*uint32[3]*/ reserved = #(0, 0, 0),
		/*FoolPackageDir_t[]*/ dirs = #(),
		files = #(),
		
		fn fpk_getFullFilePaths includeRoot:false = (
			local paths  = #()
			if dirs.count == 0 do return paths

			local dirPos  = 1         -- next unread directory
			local filePos = 1         -- next unread file
			local stack   = #()       -- #(prefix, remainDirs, remainFiles)

			/* seed with root */
			local rootPrefix = if includeRoot then (dirs[1].name + "/") else ""
			append stack #(rootPrefix,dirs[1].num_subdirs, dirs[1].num_files)
			dirPos += 1

			while stack.count > 0 do (
				local top = stack[stack.count]
				local prefix   = top[1]
				local remDirs  = top[2]
				local remFiles = top[3]

				/* ---------- emit this directory's OWN files first ---------- */
				if remFiles > 0 then (
					local f = files[filePos]
					append paths (prefix + f.name)
					stack[stack.count][3] = remFiles - 1  -- consume one file
					filePos += 1
					)
				/* ---------- then visit sub-directories -------------------- */
				else if remDirs > 0 then (
					local d = dirs[dirPos]
					stack[stack.count][2] = remDirs - 1   -- consume one subdir
					append stack #(prefix + d.name + "/",
								   d.num_subdirs,
								   d.num_files)
					dirPos += 1
					)
				/* ---------- finished this directory ----------------------- */
				else (
					deleteItem stack stack.count          -- pop
					)
				)
				paths
			),
		
		fn addDir &dirPath &ptr isRoot = (
			local dirName = if isRoot then "___RootDirectory___" else (filenameFromPath (trimRight dirPath "\\"))
			local d = FoolPackageDir_t name:dirName
			
			local subdirPaths = getDirectories (dirPath + "*")
			local filePaths = getFiles (dirPath + "*")
			
			d.num_subdirs = subdirPaths.count
			d.num_files = filePaths.count
			
			append dirs d
			for f in filePaths do (
				local fs = (getFileSize f) as integer
				local ff = FoolPackageFile_t name:(filenameFromPath f) offset:ptr length:fs
				ptr += fs
				append files ff
				)
			
			for s in subdirPaths do (
				addDir &s &ptr false
				)
			),
		
		fn fpk_buildFromFolder folderPath = (
			dirs = #()
			files = #()
			
			local ptr = 0
			
			addDir &folderPath &ptr true
			
			print dirs
			
			),
		
		fn read f = (
			
			flag4 = readLong f #unsigned
			num_dirs = readLong f #unsigned
			num_files = readLong f #unsigned
			reserved = #(readLong f #unsigned, readLong f #unsigned, readLong f #unsigned)
			
			
			--format "flag4    : \t0x%\n" (bit.IntAsHex flag4)
			--format "num_dirs : \t%\n" num_dirs
			
			dirs = #()
			if num_dirs > 0 do (
				dirs.count = num_dirs
				dirs[num_dirs] = FoolPackageDir_t()
				for i = 1 to num_dirs do (
					dirs[i] = FoolPackageDir_t()
					dirs[i].read(f)
					--format "%: %\n" (i-1) dirs[i]
					)
				)
			
			--format "num_files: \t%\n" num_files
			
			files = #()
			if num_files > 0 do (
				files.count = num_files
				files[num_files] = FoolPackageFile_t()
				for i = 1 to num_files do (
					files[i] = FoolPackageFile_t()
					files[i].read(f)
					--format "%: %\n" (i-1) files[i]
					)
				)
			

			
			)
		)

	struct FoolPackage_t (
		/*uint32*/ fileID = 0xF001FFFF,
		/*uint32*/ dateStamp = 0xF001FFFF,
		/*void  */ header = undefined,
		
		
		fn read f = (
			local files_unpacked = 0
			fileID = readLong f #unsigned
			if fileID == 0xF001FFFF or fileID == -268304385 then (
				datestamp = readLong f #unsigned
				local version = bit.shift (bit.and datestamp 0x00FF0000) -0x10
				--format "Version: \t%\n" version
				if version == 1 then (
					
					format "Error: Unsupported Version {0x%}\n" (bit.IntAsHex datestamp)
					
					)
				else if version == 2 then (
					
					header = FoolPackageHeaderV2_t()
					header.read(f)
					local data_pos = ftell f
					
					-- build folder paths
					local paths = header.fpk_getFullFilePaths()
					local build_paths = #()
					local bpath = f as string
					bpath = getFilenamePath(subString bpath 12 (bpath.count - 12))
					for x = 1 to header.files.count do (
						
						local fpath = getFilenamePath paths[x]
						local fpath_index = findItem build_paths fpath
						
						if fpath_index == 0 do (
							append build_paths fpath
							makeDir (bpath + fpath) all:true
							)
						
						
						local o = try(fopen (bpath + paths[x]) "wb")catch(undefined)
						if o != undefined then (
							fseek f (data_pos + header.files[x].offset) #seek_set
							local chunks = (header.files[x].length / 4.0) as integer
							local tail = header.files[x].length - (chunks * 4)
							
							for i = 1 to chunks do (writeLong o (readLong f))
							for i = 1 to tail do (writeByte o (readByte f))
							
							fclose o
							files_unpacked+=1
							) else (format "failed to write {%}\n" paths[x])
						)
					) else ( format "Error: Invalid Version {0x%}\n" (bit.IntAsHex datestamp) )
				
				
				--format "LastPos: \t%\n" ((ftell f) as integer)
				
				) else (format "Error: Invalid FileID {0x%}\n" (bit.IntAsHex fileID))
			if files_unpacked > 0 do (
				messageBox ((files_unpacked as string) + " files saved!")
				
				)
			),
		
		
		fn open file = (
			if file != undefined and file != "" do (
				
				local f = try(fopen file "rb")catch(undefined)
				if f != undefined then (
					read(f)
					fclose f
					) else (format "failed to open file {%}\n" file)
				)
			
			)
		
		)
	
	struct fmlObject_t ( -- 68 Bytes
		/*char[16]*/ name = "",
		/*float[4][3]*/ transform = #([0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]),
		/*uint8_t*/ num_meshes = 0,
		/*uint8_t*/ num_children = 0,
		/*uint16_t*/ unk19 = 0,
		fn read f = (
			name = ""
			for i = 1 to 16 do (
				local b = readByte f #unsigned
				if b != undefined and b > 0 then (name += bit.IntAsChar b)
				else (fseek f (16 - i) #seek_cur; exit)
				)
			transform = #(
				[readFloat f, readFloat f, readFloat f], 
				[readFloat f, readFloat f, readFloat f], 
				[readFloat f, readFloat f, readFloat f], 
				[readFloat f, readFloat f, readFloat f]
				)
			num_meshes = readByte f #unsigned
			num_children = readByte f #unsigned
			unk19 = readShort f #unsigned
			),
		fn write s = (
			for i = 1 to 16 do (
				if i <= name.count then (writeByte s (bit.CharAsInt name[i]) #unsigned)
				else (writeByte s 0)
				)
			for o in transform do (for i = 1 to 3 do (writeFloat s o[i]))
			writeByte s num_meshes #unsigned
			writeByte s num_children #unsigned
			writeShort s unk19 #unsigned
			)
		)
	
	struct fmlMesh_t ( -- 18 Bytes
		/*uint8_t*/ index = 0, -- material index to fmlMaterialName_t?
		/*uint8_t[8]*/ bone_palette = #(0, -1, -1, -1, -1, -1, -1, -1),
		/*uint8_t*/ unk11 = 0,
		/*uint16_t[4]*/ num_faces = #(0, 0, 0, 0),
		
		/*
			each layer has more weights
				example:
				
					num_faces[1] = is geometry that has one   bone weight
					num_faces[2] = is geometry that has two   bone weight
					num_faces[3] = is geometry that has three bone weight
					num_faces[4] = is geometry that has four  bone weight
		*/
		
		fn read f = (
			index = readByte f #unsigned
			bone_palette = for i = 1 to 8 collect readByte f #signed
			unk11 = readByte f #unsigned
			num_faces = for i = 1 to 4 collect readShort f #unsigned
			),
		fn write s = (
			writebyte s index #unsigned
			for o in bone_palette do writeByte s o #signed
			writebyte s unk11 #unsigned
			for o in num_faces do writeShort s o #unsigned
			)
		)
	
	struct fmlMaterialName_t ( -- 30 Bytes
		/*char[16]*/ name = "",
		/*uint8_t[14]*/ unk08 = #( \
			0, \
			0, \
			0, \
			0, \
			0, \
			0, \
			0, \
			0, \
			0, \
			0, \
			0, \ -- index to the fmlTextureName array
			0, \
			0, \
			0),
		fn read f = (
			name = ""
			for i = 1 to 16 do (
				local b = readByte f #unsigned
				if b != undefined and b > 0 then (name += bit.IntAsChar b)
				else (fseek f (16 - i) #seek_cur; exit)
				)
			unk08 = for i = 1 to 14 collect (readByte f #unsigned)
			),
		fn write s = (
			for i = 1 to 16 do (
				if i <= name.count then (writeByte s (bit.CharAsInt name[i]) #unsigned)
				else (writeByte s 0)
				)
			for o in unk08 do (writeByte s o #unsigned)
			)
		)
	
	struct fmlTextureName_t ( -- 32 Bytes
		/*char[16]*/ texture_name = "",
		/*char[16]*/ material_name = "",
		fn read f = (
			texture_name = ""
			for i = 1 to 16 do (
				local b = readByte f #unsigned
				if b != undefined and b > 0 then (texture_name += bit.IntAsChar b)
				else (fseek f (16 - i) #seek_cur; exit)
				)

			material_name = ""
			for i = 1 to 16 do (
				local b = readByte f #unsigned
				if b != undefined and b > 0 then (material_name += bit.IntAsChar b)
				else (fseek f (16 - i) #seek_cur; exit)
				)
			),
		fn write s = (
			for i = 1 to 16 do (
				if i <= texture_name.count then (writeByte s (bit.CharAsInt texture_name[i]) #unsigned)
				else (writeByte s 0)
				)
			for i = 1 to 16 do (
				if i <= material_name.count then (writeByte s (bit.CharAsInt material_name[i]) #unsigned)
				else (writeByte s 0)
				)
			)
		)
	
	struct fmlIndexMap_t ( -- 12 Bytes
		/*uint16_t*/ vertex = 0,
		/*uint16_t*/ normal = 0,
		/*uint16_t*/ tvertex = 0,
		/*uint16_t*/ vcolor = 0,
		/*uint16_t*/ boneid = 1,
		/*uint16_t*/ weight = 2,
		
		fn read f = (
			vertex = readShort f #unsigned
			normal = readShort f #unsigned
			tvertex = readShort f #unsigned
			vcolor = readShort f #unsigned
			boneid = readShort f #unsigned
			weight = readShort f #unsigned
			),
		fn write s = (
			writeShort s vertex #unsigned
			writeShort s normal #unsigned
			writeShort s tvertex #unsigned
			writeShort s vcolor #unsigned
			writeShort s boneid #unsigned
			writeShort s weight #unsigned
			)
		)

	struct fml_t (                           -- 28 bytes
		
		/*
			they reserve 3 buffers, for data that is;
			4 bytes
			6 bytes
			12 bytes
		*/
		
		/*int32_t*/ magic         = -268304432, --0xF001FFD0  -- always 0xF001FFD0
		/*uint32_t*/ date         = 0x20030107, -- 2003/01/07
		/*uint16_t*/ indexCount    = 0,
		/*uint16_t*/ unk04         = 0,
		/*uint16_t*/ buffer1Count  = 0,
		/*uint16_t*/ buffer2Count  = 0,
		/*uint16_t*/ buffer3Count  = 0,
		/*uint16_t*/ boneCount     = 0,
		/*uint16_t*/ unk07         = 0,
		/*uint16_t*/ vertCount     = 0,
		/*uint8_t */ nameBlock0    = 0,
		/*uint8_t */ nameBlock1    = 0,
		/*uint8_t */ materialCnt   = 0,
		/*uint8_t */ nameBlock3    = 0,
		
		/*uint32_t[]*/ buffer1 = #(#(255, 255, 255, 255), #(0, 255, 255, 255), #(255, 0, 0, 0)),
		/*float[3][]*/ buffer2 = #(),
		/*uint16_t[]*/ faces = #(),
		/*float[3][]*/ buffer3 = #(),
		/*fmlIndexMap_t[]*/ index = #(),
		/*char[16][]*/ joint_name = #(),
		/*char[16][]*/ texture_name = #(),
		/*fmlMaterialName_t[]*/ material_name = #(),
		/*fmlMesh_t[]*/ meshes = #(),
		/*fmlObject_t[]*/ objs = #(),
		
		fn build_org mscale:3.93701 impNormals:false impWeights:true = (
			delete objects
			
			
			local mat = undefined
			if material_name.count > 0 do (
				
				mat = MultiMaterial numsubs:material_name.count
				for i = 1 to material_name.count do (
					
					
					
					
					mat[i] = StandardMaterial()
					mat[i].name = material_name[i].name
					mat[i].diffuse = random white black
					
					mat[i].diffuseMap = Bitmaptexture filename:(texture_name[material_name[i].unk08[11] + 1].texture_name + ".tga")
					mat[i].diffuseMapEnable = off
					
					
					mat[i].glossiness = random 10 25
					mat[i].specularLevel = random 20 80
					)

				
				)
			
			
			
			local mesh_index = 1 -- 3dsmax is base 1
			local face_index = 0
			
			for o in objs do ( -- fmlObject_t
				
				if o.num_meshes == 0 do (
					local d = dummy name:o.name
					d.transform = (matrix3 \
						o.transform[1] \
						o.transform[2] \
						o.transform[3] \
						o.transform[4] \
						)
					continue
					)
				
				local vertArray = #()
				local faceArray = #()
				local normArray = #()
				local tvertArray = #()
				local matidArray = #()
				local weightArray = #()
				local boneidArray = #()
				local vcolorArray = #()
				
				local boneArray = #()--for i = 1 to joint_name.count collect (dummy name:joint_name[i]) -- create fake bones
				local bone_pos = [0.0, 0.0, 0.0]
				
				for i = 1 to joint_name.count do (
					
					local d = getNodeByName joint_name[i]
					
					if d == undefined do (
						
						d = bonesys.createbone bone_pos (bone_pos+[0,0,1]) [0,1,0]
						d.name = joint_name[i]
						d.showLinks = d.showLinksOnly = true
						d.boneEnable= false-- lets you move around the bones
						)
					append boneArray d
					)
				
				
				local matid = 1
				for m = mesh_index to (mesh_index + o.num_meshes - 1) do (
					for face_info in meshes[m].num_faces do (
						
						
						local num_faces = (face_info / 3.0) as integer
						for v = 1 to num_faces do (
							for i = 1 to 3 do (
								
								local faces_index = face_index + i
								local faces_index2 = faces[faces_index] + 1
								local vertex_index = index[faces_index2].vertex + 1
								local tvertex_index = index[faces_index2].tvertex + 1
								local normal_index = index[faces_index2].normal + 1
								
								local vcolor_index = index[faces_index2].vcolor + 1
								local boneid_index = index[faces_index2].boneid + 1
								local weight_index = index[faces_index2].weight + 1
								
								append vertArray ([buffer3[vertex_index][1], -buffer3[vertex_index][3], buffer3[vertex_index][2]] * mscale)
								append normArray [buffer2[normal_index][1], -buffer2[normal_index][3], buffer2[normal_index][2]]
								append tvertArray buffer3[tvertex_index]
								
								local wi = #()
								local bi = #()
								
								for b = 1 to 4 do (
									
									if buffer1[boneid_index][b] > -1 do (
										append wi buffer1[weight_index][b]
										append bi meshes[m].bone_palette[buffer1[boneid_index][b]+1]
										)
									)
								
								append boneidArray bi
								append weightArray wi
								
								
								append vcolorArray buffer1[vcolor_index]
								
								)
							append matidArray (meshes[m].index + 1)
							append faceArray ([1, 2, 3] + (faceArray.count * 3)) -- serilize
							face_index += 3
							)
						matid += 1
						)
					)
				
				
				local msh = mesh vertices:vertArray faces:faceArray tverts:tvertArray materialIds:matidArray
				msh.name = o.name
				msh.material = mat
				msh.transform = (matrix3 \
					o.transform[1] \
					o.transform[2] \
					o.transform[3] \
					o.transform[4] \
					)
				
				msh.backfacecull = on
				msh.displayByLayer = false
				msh.wirecolor = random (color 0 0 0) (color 255 255 255)
				

				
				buildTVFaces msh
				
				
				setNumTVerts msh tvertArray.count 
				buildTVFaces msh
				
				for i = 1 to faceArray.count do setTVFace msh i faceArray[i]
				for i = 1 to tvertArray.count do setTVert msh i tvertArray[i]
				
				
				if impNormals do (
					
					local normMod = Edit_Normals()
					addmodifier msh normMod ui:off
					select msh
					modPanel.setCurrentObject normMod
					normMod.selectBy = 1
					normMod.displayLength = 0.64516 * mscale
					normMod.MakeExplicit selection:#{1..(normArray.count)}
					local normID = #{}
					
					--apply normals
					for i = 1 to normArray.count do (
						normID = #{} --free normID
						normMod.ConvertVertexSelection #{i} &normID
						for ii in normID do (
							normMod.SetNormal ii (normalize normArray[i])
							)
						)
					
					subobjectLevel = 0
					--collapseStack msh
					)
				
				if impWeights and boneArray.count > 0 do (
					
					-- apply a skin modifier
					local skinMod = skin()
					addModifier msh skinMod ui:off
					select msh
					modPanel.setCurrentObject skinMod
					
					-- assign bones to skin modifier, from the weight pallete
					for i = 1 to boneArray.count do (
						skinOps.addbone skinMod boneArray[i]  (
							if i == boneArray.count then 1 else 0
							)
						)
					
					
					-- get names of bones in skin list
					local bneTmp = #()
					bneTmp[boneArray.count] = ""
					for i = 1 to boneArray.count do (
						bneTmp[i] = skinOps.GetBoneName skinMod i 0
						)
					
					-- create a bonemap
					local boneMap = #()
					boneMap[boneArray.count] = 1
					for i = 1 to boneArray.count do (
						boneMap[i] = 1 -- default assignment to first bone in skin list
						local bone_index = findItem bneTmp boneArray[i].name
						if bone_index > 0 do (boneMap[i] = bone_index)
						)
					
					
					-- apply weights to skin modifier
					modPanel.setCurrentObject skinMod
					for i = 1 to vertArray.count do (
						
						local bi = #()
						local bw = #()
						
						for ii = 1 to 4 do (
							
							local weight = weightArray[i][ii] / 255.0
							
							
							
							if weight > 0.00001 do (
								append bi boneMap[boneidArray[i][ii] + 1]
								append bw weight
								)
							)
						skinOps.ReplaceVertexWeights skinMod i bi bw
						
						)
					--fixEnvelopes(msh)
					--if skinOps.isWeightToolOpen skinMod == 0 do (
					--	skinOps.WeightTool skinMod
					--	)
					skinMod.filter_vertices = on
					)
				
				
				mesh_index += o.num_meshes
				
				
				
				)
			
			
			),
		
		fn fabricateBones &boneArray mscale:1.0 = (
			/* ---------- accumulators ---------------------------------- */
			local sumPos = #();  local sumW  = #()
			sumPos.count = joint_name.count
			sumW .count  = joint_name.count
			for i=1 to joint_name.count do ( sumPos[i]=[0,0,0]; sumW[i]=0 )
			
			/* ---------- track vertices we've already processed -------- */
			local seen = #();  seen.count = vertCount
			for i=1 to vertCount do seen[i]=false
			
			/* ---------- walk geometry exactly like the importer ------- */
			local meshIdx    = 1
			local faceCursor = 0
			
			for o in objs do (
				for m = meshIdx to (meshIdx + o.num_meshes - 1) do (
					local sm = meshes[m]
					
					for g = 1 to 4 do (
						local gFaceCnt = sm.num_faces[g]
						if gFaceCnt == 0 do continue
						
						local triCnt = gFaceCnt/3
						for t = 0 to triCnt-1 do (
							for c = 1 to 3 do (      -- each corner
							
								local slot = faces[faceCursor + t*3 + c] + 1
								if seen[slot] do continue        -- already handled
								seen[slot] = true
								
								/* global->file vertex maps */
								local imap = index[slot]
								local pRaw = buffer3[imap.vertex+1]
								local p    = ([pRaw.x,-pRaw.z,pRaw.y] * mscale)
								
								/* loop over 4 stored influences */
								for k = 1 to 4 do (
									local locId = buffer1[imap.boneid+1][k]     -- local to palette
									if locId > -1 do (
										local w = buffer1[imap.weight+1][k]     -- 0-255
										if w > 0 do (
											local joint = sm.bone_palette[locId+1] + 1  -- 1-based
											sumPos[joint] += p * w
											sumW [joint] += w
											)
										)
									)
								)
							)
						faceCursor += gFaceCnt
						)
					)
				meshIdx += o.num_meshes
				)
			
			/* ---------- create / move bones --------------------------- */
			boneArray = #();  boneArray.count = joint_name.count
			for bid = 1 to joint_name.count do (
				local centre = if sumW[bid] > 0 then (sumPos[bid]/sumW[bid]) else [0,0,0]
				
				local b = getNodeByName joint_name[bid]
				if b == undefined then (
					b = bonesys.createbone centre (centre+[0,0,1]) [0,1,0]
					b.name = joint_name[bid]
					b.showLinks = b.showLinksOnly = true
					b.boneEnable = false
					)
				else (
					b.position = centre
					)
				
				boneArray[bid] = b
				)
			),
		
		fn rebuildFMLHierarchy objArray = (
			struct StackItem (idx, left, wtm)          -- idx in objArray, children left, parent worldTM
			local stk   = #()
			local ident = matrix3 1

			if objs.count != objArray.count do (
				messageBox "objs.count and objArray.count differ - aborting!" title:"Import Error"
				return undefined
				)

			/*-------- main pass --------*/
			for i = 1 to objs.count do (
				local rec  = objs[i]
				local node = objArray[i]

				/*-----------------------------------------------------------
					1.  Get parent info *before* we touch the stack
				-----------------------------------------------------------*/
				local parentWTM = ident
				if stk.count > 0 do parentWTM = stk[stk.count].wtm

				/*-----------------------------------------------------------
					2.  Convert record's transform to matrix3 if needed
				-----------------------------------------------------------*/
				local localTM = (
					case (classof rec.transform) of (
						matrix3 : rec.transform
						Array   : matrix3 rec.transform[1] rec.transform[2] rec.transform[3] rec.transform[4]
						)
					)

				/*-----------------------------------------------------------
					3.  Promote local - world, then link & assign
				-----------------------------------------------------------*/
				local worldTM = localTM * parentWTM
				if stk.count > 0 do node.parent = objArray[ stk[stk.count].idx ]  -- link to parent
				at time 0 node.transform = worldTM                                -- set world TM

				/*-----------------------------------------------------------
					4.  Now that we've processed one child, decrement
						the *current* parent's counter, then pop any
						finished parents.
				-----------------------------------------------------------*/
				if stk.count > 0 do (
					stk[stk.count].left -= 1
					while (stk.count > 0 and stk[stk.count].left == 0) do
						deleteItem stk stk.count
					)

				/*-----------------------------------------------------------
					5.  Push this node if it itself owns children
				-----------------------------------------------------------*/
				if rec.num_children > 0 do (
					append stk (StackItem i rec.num_children worldTM)
					)
				)
			),
		
		fn build mscale:3.93701 impNormals:true impWeights:true = (
			
			
			/*--- material --------------------------------------------------*/
			local mat
			if material_name.count > 0 do (
				mat = multimaterial numsubs:material_name.count
				
				for i = 1 to material_name.count do (
					
					/* make sure the sub-slot exists */
					mat[i] = standardmaterial name:material_name[i].name
					
					/* * DEBUG */
					--format "\n--- Material slot % (%) ---\n" i material_name[i].name

					/* ---------- colours ---------- */
					mat[i].ambient  = color material_name[i].unk08[2]  material_name[i].unk08[3]  material_name[i].unk08[4]
					mat[i].diffuse  = color material_name[i].unk08[5]  material_name[i].unk08[6]  material_name[i].unk08[7]
					mat[i].specular = color material_name[i].unk08[8]  material_name[i].unk08[9]  material_name[i].unk08[10]

					mat[i].useSelfIllumColor = on
					mat[i].selfIllumColor    = color material_name[i].unk08[12] material_name[i].unk08[13] material_name[i].unk08[14]
					mat[i].useSelfIllumColor = off
					/* ---------- bitmap ---------- */
					local texIdx = material_name[i].unk08[11]          -- game stores 0-based (-1 = none)
					if texIdx != 255 and texIdx < texture_name.count then (
						local texRec = texture_name[texIdx + 1]        -- MaxScript is 1-based
						local bmpPath = texRec.material_name + ".dds"

						mat[i].diffuseMap        = bitmaptexture filename:bmpPath
						mat[i].diffuseMapEnable  = off
						mat[i].diffuseMap.name   = texRec.texture_name
						mat.names[i]             = texRec.texture_name

						/* * DEBUG */
						--format "   | diffuseMap  : %\n" bmpPath
						)
					else (
						/* * DEBUG */
						--format "   | no diffuseMap (texIdx = %)\n" texIdx
						)

					/* ---------- shading params ---------- */
					mat[i].specularLevel = material_name[i].unk08[1]   -- Level stored in element 1
					mat[i].glossiness    = 20

					/* * DEBUG */
					--format "   ambient : %\n" mat[i].ambient
					--format "   diffuse : %\n" mat[i].diffuse
					--format "   specular: % (level %)\n" mat[i].specular mat[i].specularLevel
					--format "   selfIllum: %\n" mat[i].selfIllumColor
					)
				)

			
			/*--- synthetic bones -------------------------------------------*/
			local boneArray = #()
			fabricateBones &boneArray mscale:mscale           -- fills boneArray
			
			/*--- import geometry -------------------------------------------*/
			local meshIdx    = 1
			local faceCursor = 0
			local objArray = #()
			for o in objs do (
				if o.num_meshes == 0 do (
					local d = dummy name:o.name transform:(matrix3 o.transform[1] o.transform[2] o.transform[3] o.transform[4])
					append objArray d
					continue
					)
				
				/* per-object arrays */
				local vertArr=#(); normArr=#(); tvertArr=#(); faceArr=#(); matArr=#()
				local boneidArr=#(); weightArr=#()
				local vmap=#(); vmap.count = vertCount; for k=1 to vertCount do vmap[k]=0
				
				
				for m = meshIdx to (meshIdx+o.num_meshes-1) do (
					local sm = meshes[m]
					for g=1 to 4 do (
						local gFaceCnt = sm.num_faces[g]
						if gFaceCnt==0 do continue
						local triCnt = gFaceCnt/3
						for t=0 to triCnt-1 do (
							local tri=#()
							for c=1 to 3 do (
								local globalFace = faces[faceCursor+t*3+c]+1
								local li = vmap[globalFace]
								if li==0 do (
									local imap = index[globalFace]
									local p = buffer3[imap.vertex+1]
									append vertArr ([p.x,-p.z,p.y]*mscale)
									local uv = buffer3[imap.tvertex+1]
									append tvertArr [uv.x,1-uv.y,0]
									local n16 = buffer2[imap.normal+1]
									append normArr (normalize [n16.x,-n16.z,n16.y])
									
									if impWeights do (
										local bids=#(); local wts=#()
										for b=1 to 4 do (
											local id=buffer1[imap.boneid+1][b]
											if id>-1 do (
												append wts buffer1[imap.weight+1][b]
												append bids sm.bone_palette[id+1]
												)
											)
										append boneidArr bids
										append weightArr wts
										)
									li=vertArr.count; vmap[globalFace]=li
									)
								append tri li
								)
							append faceArr [tri[3],tri[1],tri[2]]
							append matArr (sm.index + 1)
							)
						faceCursor+=gFaceCnt
						)
					
					)
				
				/* bake mesh */
				local msh = mesh vertices:vertArr faces:faceArr tverts:tvertArr materialIds:matArr
				msh.name=o.name
				msh.transform=(matrix3 o.transform[1] o.transform[2] o.transform[3] o.transform[4])
				msh.backfacecull=on; msh.material=mat
				buildTVFaces msh; setNumTVerts msh tvertArr.count
				for f=1 to faceArr.count do (
					meshop.setMapFace msh 1 f faceArr[f]
					setFaceMatID msh f matArr[f]
					)
				for tv=1 to tvertArr.count do setTVert msh tv tvertArr[tv]
				
				if impNormals do (
					local en = Edit_Normals(); addModifier msh en ui:off
					select msh; modPanel.setCurrentObject en
					en.selectBy=1; en.makeExplicit selection:#{1..normArr.count}
					local idset=#{}
					for v=1 to normArr.count do (
						idset=#{}; en.ConvertVertexSelection #{v} &idset
						for i in idset do en.SetNormal i normArr[v]
						)
					subobjectLevel=0
					)
				
				if impWeights and boneArray.count>0 do (
					local sk=skin(); addModifier msh sk ui:off
					select msh; modPanel.setCurrentObject sk
					for b=1 to boneArray.count do skinOps.addBone sk boneArray[b] (if b==boneArray.count then 1 else 0)
					local names = for i=1 to boneArray.count collect skinOps.getBoneName sk i 0
					local map   = for i=1 to boneArray.count collect (findItem names boneArray[i].name)
					for v=1 to vertArr.count do (
						local bi=#(); local bw=#()
						for i=1 to boneidArr[v].count do (
							local w=weightArr[v][i]/255.0
							if w>1e-5 do (append bi map[boneidArr[v][i]+1]; append bw w)
							)
						skinOps.ReplaceVertexWeights sk v bi bw
						)
					sk.filter_vertices=on
					)
				append objArray msh
				meshIdx+=o.num_meshes
				)
			rebuildFMLHierarchy(objArray)
			format "Import finished - % objects, % bones\n" objs.count boneArray.count
			),
		
		fn export mscale:3.93701 = (
			setCommandPanelTaskMode #modify

			/* -------- clear previous state --------------------------- */
			buffer1=#(); buffer2=#(); buffer3=#()
			faces=#();  index=#();  meshes=#()
			objs=#();   material_name=#(); texture_name=#(); joint_name=#()

			/* -------- global unique lists ---------------------------- */
			local posList=#(); local posKeyList=#()
			local nrmList=#(); local nrmKeyList=#()
			local uvList =#(); local uvKeyList =#()
			local bwKeyList=#()             -- bone+weight quartet
			local idxKeyList=#()            -- (p,n,uv,bw) tuple

			local qPos=100000.0      -- 1 × 10-5
			local qUV =10000.0       -- 1 × 10-4

			/* -------- collect all joint names ------------------------ */
			for o in objects do (
				if (classof o == BoneGeometry) then append joint_name o.name
				else if (classof o == Dummy and matchPattern o.name pattern:"bone_*") do append joint_name o.name
				)
			boneCount = joint_name.count

			local meshGlobalIdx=1

			/* =========================================================
			   main scene traversal
			   ======================================================= */
			for n in objects do (
				local oRec=fmlObject_t()
				oRec.name=n.name
				oRec.transform=#(n.transform.row1,n.transform.row2,n.transform.row3,n.transform.row4)
				oRec.num_children=n.children.count
				
				
				/* ---------- skip bones -------------------- */
				if classof n == BoneGeometry or MatchPattern n.name pattern:"bone_*" or MatchPattern n.name pattern:"j_*" do (
					
					continue
					)
				
				
				/* ---------- hierarchy-only dummy -------------------- */
				if classof n == Dummy or classof n == BoneGeometry do (
					oRec.num_meshes=0
					append objs oRec
					continue
					)

				/* ---------- skip non-geometry ----------------------- */
				if superClassOf n != GeometryClass and ((classOf n != Editable_Mesh) or (classOf n != Editable_Poly)) do (
					append objs oRec
					continue
					)
				
				/* ---------- guarantee UV channel ------------------- */
				local uvMod=Unwrap_UVW(); select n
				modPanel.addModToSelection uvMod ui:off
				local msh=snapshotAsMesh n
				deleteModifier n uvMod
				
				if (getNumFaces msh)==0 do (
					append objs oRec
					delete msh
					continue
					)

				/* ---------- skin data lookup ----------------------- */
				local skinMod=undefined
				for m in n.modifiers where (classof m == Skin) do (skinMod=m; exit)

				local vBones=#(); vBones.count=getNumVerts msh
				local vWts  =#(); vWts.count  =vBones.count

				if skinMod!=undefined then (
					modPanel.setCurrentObject skinMod
					for v=1 to vBones.count do (
						local ids=#(); local wts=#()
						local c=skinOps.getVertexWeightCount skinMod v
						for k=1 to c do (
							local bid =skinOps.getVertexWeightBoneID skinMod v k
							local wt  =skinOps.getVertexWeight     skinMod v k
							local bnm =skinOps.getBoneName         skinMod bid 0
							local j   =findItem joint_name bnm
							if j>0 do (append ids (j-1); append wts wt)
							)
						while ids.count>4 do (
							local mi=1; for i=2 to wts.count do if wts[i]<wts[mi] do mi=i
							deleteItem ids mi; deleteItem wts mi
							)
						local s=0.0; for w in wts do s+=w
						if s>0 do for i=1 to wts.count do wts[i]=wts[i]/s
						vBones[v]=ids; vWts[v]=wts
						)
					)
				else (for v=1 to vBones.count do (vBones[v]=#(); vWts[v]=#()))

				/* ---------- sub-materials -------------------------- */
				local subMats=#()
				if n.material!=undefined and isProperty n.material #materialList then (
					subMats=n.material.materialList
					)
				else subMats=#(n.material)
				if subMats.count==0 do (
					
					subMats=#(StandardMaterial name:("mat_"+n.name))
					format "Error: No Materials for {%}\n" n.name
					)

				/* ========== per sub-material ====================== */
				for smID=1 to subMats.count do (
					/* faces with this material */
					local matFaces=#()
					for f=1 to getNumFaces msh do (
						local mf=getFaceMatID msh f
						if mf==smID or (mf==0 and smID==1) do append matFaces f
						)
					if matFaces.count==0 do continue

					/*---------------------------------------------------------------
						 Resolve a stable material record (create if missing)
					  -------------------------------------------------------------*/
					local mName = try (subMats[smID].name) catch ("mat_" + n.name + "_" + smID as string)

					-- look up by name
					local mIdx = 0
					for j = 1 to material_name.count while mIdx == 0 do
						if material_name[j].name == mName do mIdx = j

					-- create a fresh record if none exists
					if mIdx == 0 do (
						local mr = fmlMaterialName_t()
						mr.name  = mName
						-- mr.unk08 is already #(0,0, ...) from the struct default
						append material_name mr
						mIdx = material_name.count
						)

					/*---------------------------------------------------------------
						 Copy colour & shading data into unk08[ ]
						   Index mapping (same as your importer):
						   [2-4] Ambient   RGB
						   [5-7] Diffuse   RGB
						   [8-10] Specular RGB   (we also store specularLevel in [8])
						   [11]  Texture   index  (-1 = none; game uses 0-based)
						   [12-14] Self-illum RGB
					  -------------------------------------------------------------*/
					local matRef = subMats[smID]      -- StandardMaterial (or undefined)

					if matRef != undefined do (
						
						case (classof matRef) of (
							(StandardMaterial): (
								
								/* ---- ambient ---- */
								local a = matRef.ambient
								material_name[mIdx].unk08[2] = a.r as integer
								material_name[mIdx].unk08[3] = a.g as integer
								material_name[mIdx].unk08[4] = a.b as integer

								/* ---- diffuse ---- */
								local d = matRef.diffuse
								material_name[mIdx].unk08[5] = d.r as integer
								material_name[mIdx].unk08[6] = d.g as integer
								material_name[mIdx].unk08[7] = d.b as integer

								/* ---- specular colour + level ---- */
								material_name[mIdx].unk08[1]  = matRef.specularLevel as integer   -- level
								
								material_name[mIdx].unk08[8]  = matRef.specular.r  as integer
								material_name[mIdx].unk08[9] = matRef.specular.g  as integer
								material_name[mIdx].unk08[10] = matRef.specular.b  as integer
								
								material_name[mIdx].unk08[11] = -1   -- reset texture slot for now

								/* ---- self-illum ---- */
								local s = matRef.selfIllumColor
								material_name[mIdx].unk08[12] = s.r as integer
								material_name[mIdx].unk08[13] = s.g as integer
								material_name[mIdx].unk08[14] = s.b as integer
								
								if matRef.diffuseMap != undefined do (
									local bmpName = getFilenameFile matRef.diffuseMap.filename   -- without extension
									local mapName = matRef.diffuseMap.name
									
									/* look for existing texture record */
									local tIdx = 0
									for t = 1 to texture_name.count while tIdx == 0 do
										if texture_name[t].texture_name == bmpName do tIdx = t

									/* create new texture record if needed */
									if tIdx == 0 do (
										local tr = fmlTextureName_t()
										tr.material_name = bmpName
										tr.texture_name  = mapName
										append texture_name tr
										tIdx = texture_name.count
										)

									/* store zero-based texture index in material.unk08[11] */
									material_name[mIdx].unk08[11] = tIdx - 1   -- game expects 0-based
									)

								)
							(PhysicalMaterial): (
								/* ---- ambient ---- */
								local a = matRef.trans_color
								material_name[mIdx].unk08[2] = a.r as integer
								material_name[mIdx].unk08[3] = a.g as integer
								material_name[mIdx].unk08[4] = a.b as integer

								/* ---- diffuse ---- */
								local d = matRef.base_color
								material_name[mIdx].unk08[5] = d.r as integer
								material_name[mIdx].unk08[6] = d.g as integer
								material_name[mIdx].unk08[7] = d.b as integer

								/* ---- specular colour + level ---- */
								material_name[mIdx].unk08[1]  = (matRef.reflectivity * 255.0) as integer   -- level
								
								local p = matRef.refl_color
								material_name[mIdx].unk08[8]  = p.r  as integer
								material_name[mIdx].unk08[9] = p.g  as integer
								material_name[mIdx].unk08[10] = p.b  as integer
								
								material_name[mIdx].unk08[11] = -1   -- reset texture slot for now

								/* ---- self-illum ---- */
								local s = matRef.emit_color
								material_name[mIdx].unk08[12] = s.r as integer
								material_name[mIdx].unk08[13] = s.g as integer
								material_name[mIdx].unk08[14] = s.b as integer
								
								if matRef.base_color_map != undefined and classof matRef.base_color_map == Bitmaptexture do (
									local bmpName = getFilenameFile matRef.base_color_map.filename   -- without extension
									local mapName = matRef.base_color_map.name
									
									/* look for existing texture record */
									local tIdx = 0
									for t = 1 to texture_name.count while tIdx == 0 do
										if texture_name[t].texture_name == bmpName do tIdx = t

									/* create new texture record if needed */
									if tIdx == 0 do (
										local tr = fmlTextureName_t()
										tr.material_name = bmpName
										tr.texture_name  = mapName
										append texture_name tr
										tIdx = texture_name.count
										)
									/* store zero-based texture index in material.unk08[11] */
									material_name[mIdx].unk08[11] = tIdx - 1   -- game expects 0-based
									)
								)
							(OpenPBR_Material): (
								/* ---- ambient ---- */
								local a = matRef.transmission_color
								material_name[mIdx].unk08[2] = a.r as integer
								material_name[mIdx].unk08[3] = a.g as integer
								material_name[mIdx].unk08[4] = a.b as integer

								/* ---- diffuse ---- */
								local d = matRef.base_color
								material_name[mIdx].unk08[5] = d.r as integer
								material_name[mIdx].unk08[6] = d.g as integer
								material_name[mIdx].unk08[7] = d.b as integer

								/* ---- specular colour + level ---- */
								material_name[mIdx].unk08[1]  = (matRef.specularLevel * 255.0) as integer   -- level
								
								local p = matRef.specular_color
								material_name[mIdx].unk08[8]  = p.r  as integer
								material_name[mIdx].unk08[9] = p.g  as integer
								material_name[mIdx].unk08[10] = p.b  as integer
								
								material_name[mIdx].unk08[11] = -1   -- reset texture slot for now

								/* ---- self-illum ---- */
								local s = matRef.emission_color
								material_name[mIdx].unk08[12] = s.r as integer
								material_name[mIdx].unk08[13] = s.g as integer
								material_name[mIdx].unk08[14] = s.b as integer
								
								if matRef.base_color_map != undefined and classof matRef.base_color_map == Bitmaptexture do (
									local bmpName = getFilenameFile matRef.base_color_map.filename   -- without extension
									local mapName = matRef.base_color_map.name
									
									/* look for existing texture record */
									local tIdx = 0
									for t = 1 to texture_name.count while tIdx == 0 do
										if texture_name[t].texture_name == bmpName do tIdx = t

									/* create new texture record if needed */
									if tIdx == 0 do (
										local tr = fmlTextureName_t()
										tr.material_name = bmpName
										tr.texture_name  = mapName
										append texture_name tr
										tIdx = texture_name.count
										)

									/* store zero-based texture index in material.unk08[11] */
									material_name[mIdx].unk08[11] = tIdx - 1   -- game expects 0-based
									)
								)
							
							)
						
						
						)


					/* ---------- split loop (32 767 / 8) ------------- */
					local ptr=1
					while ptr<=matFaces.count do (
						local fBatch=#(); local palette=#(); local bin=#(0,0,0,0)

						while ptr<=matFaces.count do (
							local fid=matFaces[ptr]
							local fd =getFace msh fid
							local fbones=#()
							for c=1 to 3 do (
								local vi=fd[c]
								for b in vBones[vi] do if (findItem fbones b)==0 do append fbones b
								)
							local palTest=palette
							for b in fbones do if (findItem palTest b)==0 do append palTest b
							if fBatch.count>=32767 or palTest.count>8 then exit

							append fBatch fid; palette=palTest
							local bc=fbones.count; if bc<1 then bc=1 else if bc>4 then bc=4
							bin[bc]+=3; ptr+=1
							)

						/* sort palette so slot mapping is deterministic */
						qsort palette (fn c a b = if a<b then -1 else if a>b then 1 else 0)

						/* create mesh header */
						local fm=fmlMesh_t()
						fm.index        =mIdx - 1--meshGlobalIdx
						fm.num_faces    =bin
						fm.bone_palette =#(-1,-1,-1,-1,-1,-1,-1,-1)
						for p=1 to palette.count do fm.bone_palette[p]=palette[p]
						append meshes fm; meshGlobalIdx+=1; oRec.num_meshes+=1

						/* remap per vertex */
						local vRemap=#(); vRemap.count=getNumVerts msh

						for fid in fBatch do (
							local fd=getFace msh fid
							local tv=getTVFace msh fid

							for c=1 to 3 do (
								local vi=fd[c]
								if vRemap[vi]==undefined do (
									/* --- position key */
									local p=getVert msh vi; local pp=[p.x,p.z,-p.y]/mscale
									local kx=(floor(pp.x*qPos+0.5)) as integer
									local ky=(floor(pp.y*qPos+0.5)) as integer
									local kz=(floor(pp.z*qPos+0.5)) as integer
									local pKey=kx as string+","+ky as string+","+kz as string
									local pIdx=findItem posKeyList pKey
									if pIdx==0 do (append posKeyList pKey; append posList pp; pIdx=posList.count)

									/* --- normal key */
									local n=getNormal msh vi; local nn=[n.x,n.z,-n.y]
									local nx=(floor(nn.x*qPos+0.5)) as integer
									local ny=(floor(nn.y*qPos+0.5)) as integer
									local nz=(floor(nn.z*qPos+0.5)) as integer
									local nKey=nx as string+","+ny as string+","+nz as string
									local nIdx=findItem nrmKeyList nKey
									if nIdx==0 do (append nrmKeyList nKey; append nrmList nn; nIdx=nrmList.count)

									/* --- UV key */
									local u=getTVert msh tv[c]; local up=[u.x,(1-u.y),0]
									local ux=(floor(up.x*qUV+0.5)) as integer
									local uy=(floor(up.y*qUV+0.5)) as integer
									local uvKey=ux as string+","+uy as string
									local uvIdx=findItem uvKeyList uvKey
									if uvIdx==0 do (append uvKeyList uvKey; append uvList up; uvIdx=uvList.count)

									/* --- bone/weight canonical */
									local tmpID=copy vBones[vi] #nomap; local tmpWT=copy vWts[vi] #nomap
									for a=1 to tmpID.count-1 do
										for b=a+1 to tmpID.count do
											if (tmpWT[b]>tmpWT[a]) or \
											   ((abs(tmpWT[b]-tmpWT[a])<1e-6) and tmpID[b]<tmpID[a]) do (
												swap tmpWT[a] tmpWT[b]; swap tmpID[a] tmpID[b]
												)
									local boneEntry=#(-1,-1,-1,-1); local wtEntry=#(0,0,0,0)
									for b=1 to tmpID.count do (
										local slot=findItem palette tmpID[b]
										if slot>0 do (boneEntry[b]=slot-1; wtEntry[b]=(tmpWT[b]*255.0) as integer)
										)
									local bwKey=(boneEntry as string)+"|"+(wtEntry as string)
									local pairIdx=findItem bwKeyList bwKey
									if pairIdx==0 then (
										append bwKeyList bwKey
										append buffer1 boneEntry; append buffer1 wtEntry
										pairIdx=(bwKeyList.count-1)*2
										)
									else pairIdx=(pairIdx-1)*2

									/* --- create/reuse fmlIndexMap_t */
									local iKey=pIdx as string+"|"+nIdx as string+"|"+uvIdx as string+"|"+pairIdx as string
									local idx=findItem idxKeyList iKey
									if idx==0 then (
										local im=fmlIndexMap_t()
										im.vertex =pIdx-1; im.normal=nIdx-1; im.tvertex=uvIdx-1
										im.boneid =pairIdx; im.weight=pairIdx+1
										append index im
										append idxKeyList iKey
										idx=index.count-1
										)
									else idx-=1   -- convert to 0-based

									vRemap[vi]=idx
									)
								append faces vRemap[vi]
								)
							)
						)--while split
					)--material loop

				append objs oRec
				delete msh
				)--nodes

			/* ---------- flush position + UV to buffer3 -------------- */
			buffer3 = posList
			local uvOffset = buffer3.count
			for u in uvList do append buffer3 u
			for i=1 to index.count do index[i].tvertex += uvOffset
			buffer2 = nrmList

			/* ---------- header counts ------------------------------- */
			indexCount   = index.count
			buffer1Count = buffer1.count
			buffer2Count = buffer2.count
			buffer3Count = buffer3.count
			vertCount    = buffer3.count
			materialCnt  = material_name.count
			nameBlock0   = joint_name.count
			nameBlock1   = texture_name.count
			nameBlock3   = material_name.count

			format "EXPORT COMPLETE | Obj:% Mesh:% Bones:%  Vert:%  UV:%  Nrm:%  BW:%  Idx:%  Faces:%\n" \
				objs.count meshes.count boneCount posList.count uvList.count nrmList.count bwKeyList.count index.count faces.count

		   
			),



		
		fn readFixedString f strlen = (
			local s = "", b = 1
			if strlen == undefined do format "Failed at %\n" (ftell f)
			for i = 1 to strlen do (
				b = readbyte f #unsigned
				if b == undefined do format "Failed at %\n" (ftell f)
				if b > 0 then (
					s += bit.IntAsChar b
					)
				else (
					fseek f (strlen - i) #seek_cur
					exit
					)
				)
			s
			),
		
		fn read f verbose:false = (
			magic         = readLong  f #signed
			date         = readLong f #unsigned
			indexCount    = readShort f #unsigned
			unk04         = readShort f #unsigned
			buffer1Count  = readShort f #unsigned
			buffer2Count  = readShort f #unsigned
			buffer3Count  = readShort f #unsigned
			boneCount     = readShort f #unsigned
			unk07         = readShort f #unsigned
			vertCount     = readShort f #unsigned
			nameBlock0    = readByte  f #unsigned
			nameBlock1    = readByte  f #unsigned
			materialCnt   = readByte  f #unsigned
			nameBlock3    = readByte  f #unsigned
			
			
			if verbose do (
				format "magic        : \t%\n" (magic)
				format "date        : \t%\n" (date)
				format "indexCount  *: \t%\n" (indexCount)
				format "unk04        : \t%\n" (unk04)
				format "buffer1Count  : \t%\n" (buffer1Count)
				format "buffer2Count  : \t%\n" (buffer2Count)
				format "buffer3Count: \t%\n" (buffer3Count)
				format "boneCount    : \t%\n" (boneCount)
				format "vertCount    : \t%\n" (vertCount)
				format "nameBlock0   : \t%\n" (nameBlock0)
				format "nameBlock1   : \t%\n" (nameBlock1)
				format "materialCnt  : \t%\n" (materialCnt)
				format "nameBlock3   : \t%\n" (nameBlock3)
				
				)
			
			
			if verbose do (format "WEIGHTS: \t%\n" ((ftell f) as integer))
			buffer1 = #() -- 4 byte buffer
			if buffer1Count > 0 do (
				buffer1.count = buffer1Count
				buffer1[buffer1Count] = 0
				for i = 1 to buffer1Count do (
					buffer1[i] = #(readByte f #unsigned, readByte f #unsigned, readByte f #unsigned, readByte f #unsigned)
					)
				)
			
			if verbose do (format "NORMS: \t%\n" ((ftell f) as integer))
			buffer2 = #() -- 6 byte buffer
			if buffer2Count > 0 do (
				buffer2.count = buffer2Count
				buffer2[buffer2Count] = 0
				for i = 1 to buffer2Count do (
					buffer2[i] = [readShort f #signed, readShort f #signed, readShort f #signed] / 32767.0
					)
				)
			
			if verbose do (format "FACES: \t%\n" ((ftell f) as integer))
			faces = #() -- 2 byte buffer
			if indexCount > 0 do (
				faces.count = indexCount
				faces[indexCount] = 0
				for i = 1 to indexCount do (
					faces[i] = readShort f #unsigned
					)
				)
			
			if verbose do (format "VERTS: \t%\n" ((ftell f) as integer))
			buffer3 = #() -- 12 byte buffer
			if buffer3Count > 0 do (
				buffer3.count = buffer3Count
				buffer3[buffer3Count] = 0
				for i = 1 to buffer3Count do (
					buffer3[i] = [readFloat f, readFloat f, readFloat f]
					)
				)
			
			if verbose do (format "INDEX: \t%\n" ((ftell f) as integer))
			index = #()
			if vertCount > 0 do (
				index.count = vertCount
				index[vertCount] = fmlIndexMap_t()
				for i = 1 to vertCount do (
					index[i] = fmlIndexMap_t()
					index[i].read(f)
					)
				)
			
			if verbose do (format "JOINT: \t%\n" ((ftell f) as integer))
			joint_name = #()
			if nameBlock0 > 0 do (
				joint_name.count = nameBlock0
				joint_name[nameBlock0] = ""
				for i = 1 to nameBlock0 do (
					joint_name[i] = readFixedString f 16
					)
				)
			
			if verbose do (format "TEXES: \t%\n" ((ftell f) as integer))
			texture_name = #()
			if nameBlock1 > 0 do (
				texture_name.count = nameBlock1
				texture_name[nameBlock1] = fmlTextureName_t()
				for i = 1 to nameBlock1 do (
					texture_name[i] = fmlTextureName_t()
					texture_name[i].read(f)
					)
				)
			
			if verbose do (format "MATRS: \t%\n" ((ftell f) as integer))
			material_name = #()
			if materialCnt > 0 do (
				material_name.count = materialCnt
				material_name[materialCnt] = fmlMaterialName_t()
				for i = 1 to materialCnt do (
					material_name[i] = fmlMaterialName_t()
					material_name[i].read(f)
					)
				)
			
			if verbose do (format "MESHS: \t%\n" ((ftell f) as integer))
			meshes = #()
			if unk07 > 0 do (
				meshes.count = unk07
				meshes[unk07] = fmlMesh_t()
				for i = 1 to unk07 do (
					meshes[i] = fmlMesh_t()
					meshes[i].read(f)
					)
				)
			
			if verbose do (format "OBJS : \t%\n" ((ftell f) as integer))
			objs = #()
			if boneCount > 0 do (
				objs.count = boneCount
				objs[boneCount] = fmlObject_t()
				for i = 1 to boneCount do (
					objs[i] = fmlObject_t()
					objs[i].read(f)
					)
				)
			

			local highVal = #()
			if verbose do (
				print "INDEX TABLE"
				format "Count: \t%\n" index.count
-- 				for i = 1 to 20 do (
-- 					if i > index.count do exit
-- 					print index[i]
-- 					)
				
				--print (index )
-- 				for o in index do (
-- 					appendIfUnique highVal o.buffer3
-- 					appendIfUnique highVal o.buffer2

-- 					)
-- 				sort highVal
-- 				print highVal
				)
			
			if verbose do (
-- 				print "faces"
-- 				sort faces
-- 				print (faces )
				)
			
			if verbose do (
				print "OBJS  TABLE"
				print (objs )
				)
			
			if verbose do (
				print "MESHS TABLE"
				print (meshes )
				)
			
			if verbose do (
-- 				print "WEIGHT TABLE"
-- 				for i = 1 to buffer1.count do (
-- 					format "%: %\n" i buffer1[i]
-- 					)
				)
			
			if verbose do (
				print "JOINT TABLE"
				print (joint_name as string)
				)
			
			if verbose do (
				print "TEXES TABLE"
				print (texture_name)
				)
			
			if verbose do (
				print "MATRS TABLE"
				print (material_name )
				)
			
			),
			
		fn write &s = (
			writeLong s magic #signed
			writeLong s date #unsigned
			writeShort s (indexCount=faces.count) #unsigned
			writeShort s unk04 #unsigned
			writeShort s (buffer1Count=buffer1.count) #unsigned
			writeShort s (buffer2Count=buffer2.count) #unsigned
			writeShort s (buffer3Count=buffer3.count) #unsigned
			writeShort s (boneCount=objs.count) #unsigned
			writeShort s (unk07=meshes.count) #unsigned
			writeShort s (vertCount=index.count) #unsigned
			writeByte s (nameBlock0=joint_name.count) #unsigned
			writeByte s (nameBlock1=texture_name.count) #unsigned
			writeByte s (materialCnt=material_name.count) #unsigned
			writeByte s (nameBlock3=joint_name.count) #unsigned -- ????
			
			
			for o in buffer1 do (for v in o do (writeByte s v #signed))
			for o in buffer2 do (for i = 1 to 3 do (writeShort s (o[i] * 32767) #signed))
			for o in faces do (writeShort s o #unsigned)
			for o in buffer3 do (for i = 1 to 3 do (writeFloat s o[i]))
			for o in index do (o.write(s))
			for o in joint_name do (
				for i = 1 to 16 do (
					if i <= o.count then (writeByte s (bit.CharAsInt o[i]) #unsigned)
					else (writeByte s 0)
					)
				)
			for o in texture_name do (o.write(s))
			for o in material_name do (o.write(s))
			for o in meshes do (o.write(s))
			for o in objs do (o.write(s))
			),
		
		fn open file = (
			if file != undefined and file != "" do (
				local f = try(fopen file "rb")catch(undefined)
				if f != undefined then (
					read(f)
					with undo off (
						with redraw off (
							
							build()
							)
						)
					fclose f
					) else (format "failed to open file {%}\n")
				)
			),
		
		fn save file = (
			if file != undefined and file != "" do (
				local s = try(fopen file "wb")catch(undefined)
				if s != undefined then (
-- 					with undo off (
-- 						with redraw off (
-- 							export()
-- 							)
-- 						)
					write(&s)
					fclose s
					) else (format "failed to save file {%}\n")
				)
			)
		
		)

	fn read file = (
		if file != undefined and file != "" do (
			local f = try(fopen file "rb")catch(undefined)
			if f != undefined then (
				local fml = fml_t()
				fml.read(f)
				with undo off (
					with redraw off (
						if chk_clear.checked do (delete objects)
						--delete objects
						fml.build()
						--fml.save(file+"_resave.fml")
						)
					)
				fclose f
				) else (format "failed to open file {%}\n")
			)
		)
	
	fn write file = (
		if file != undefined and file != "" do (
			local fml = fml_t()
			with undo off (
				with redraw off (
					fml.export()
					)
				)
			fml.save(file)
			)
		)

	fn pack_fpk file = (
		local fpk = FoolPackage_t()
		fpk.header = FoolPackageHeaderV2_t()
		fpk.header.fpk_buildFromFolder("E:\\BackUp\\MyCloud4100\\Coding\\Cpp\\Projects\\RAW2\\bin\\Release\\KajiFiles")
-- 		print (fpk.header.fpk_getFullFilePaths())
		
		print (fpk.header.files)
		
		)
	
	fn unpack_fpk file = (
		if file != undefined and file != "" do (
			local fpk = FoolPackage_t()
			fpk.open(file)
			)
		)
	
    on raw2 open do (
		
        -- Find property indices
        local idxX    = fileProperties.findProperty #custom "rrxx_util_x"
        local idxY    = fileProperties.findProperty #custom "rrxx_util_y"

        -- If position properties exist, retrieve them and set dialog position
        if (idxX != 0) and (idxY != 0) do (
            local storedX = fileProperties.getPropertyValue #custom idxX
            local storedY = fileProperties.getPropertyValue #custom idxY
            
            -- Convert to integer and set rollout position
            setDialogPos raw2 [storedX as integer, storedY as integer]
			)
		)
    -- on rollout close
    on raw2 close do (
        local p = getDialogPos raw2
		
        -- Add or overwrite #custom properties
        fileProperties.addProperty #custom "rrxx_util_x" p.x
        fileProperties.addProperty #custom "rrxx_util_y" p.y
		)
	
	
	on btn_import pressed do (
		read (
			GetOpenFileName \
				caption:"Open Fool Model" \
				types: "model (*.fml)|*.fml|All files (*.*)|*.*|"
			)
		)
	
	on btn_export pressed do (
		write (
			GetSaveFileName \
				caption:"Open Fool Model" \
				types: "model (*.fml)|*.fml|All files (*.*)|*.*|"
			)
		)
	
	on btn_unpack pressed do (
		unpack_fpk (
			GetOpenFileName \
				caption:"Open Fool Package" \
				types: "Package (*.fpk)|*.fpk|All files (*.*)|*.*|"
			)
		)
	
	local gFML
	local _matClipboard = #()
	local _undoStack = #()

	fn cloneMatArray arr = (
		local out=#()
		out.count=arr.count
		local i=1
		while i<=arr.count do (
			local s=fmlMaterialName_t()
			s.name = arr[i].name
			s.unk08 = copy arr[i].unk08 #nomap
			out[i]=s
			i+=1
			)
		out
		)

	fn cloneTexArray arr = (
		local out=#()
		out.count=arr.count
		local i=1
		while i<=arr.count do (
			local s=fmlTextureName_t()
			s.texture_name = arr[i].texture_name
			s.material_name = arr[i].material_name
			out[i]=s
			i+=1
			)
		out
		)

	fn cloneMeshArray arr = (
		local out=#()
		out.count=arr.count
		local i=1
		while i<=arr.count do (
			local s=fmlMesh_t()
			s.index = arr[i].index
			s.bone_palette = copy arr[i].bone_palette #nomap
			s.num_faces = copy arr[i].num_faces #nomap
			out[i]=s
			i+=1
			)
		out
		)

	fn cloneObjArray arr = (
		local out=#()
		out.count=arr.count
		local i=1
		while i<=arr.count do (
			local s=fmlObject_t()
			s.name = arr[i].name
			s.transform = copy arr[i].transform #nomap
			s.num_meshes = arr[i].num_meshes
			s.num_children = arr[i].num_children
			out[i]=s
			i+=1
			)
		out
		)

	fn cloneIndexArray arr = (
		local out=#()
		out.count=arr.count
		local i=1
		while i<=arr.count do (
			local s=fmlIndexMap_t()
			s.vertex = arr[i].vertex
			s.normal = arr[i].normal
			s.tvertex = arr[i].tvertex
			s.vcolor = arr[i].vcolor
			s.boneid = arr[i].boneid
			s.weight = arr[i].weight
			out[i]=s
			i+=1
			)
		out
		)

	fn cloneFML src = (
		local dest = undefined
		if src != undefined do (
			dest = fml_t()
			dest.index = cloneIndexArray src.index
			dest.joint_name = copy src.joint_name #nomap
			dest.texture_name = cloneTexArray src.texture_name
			dest.material_name = cloneMatArray src.material_name
			dest.meshes = cloneMeshArray src.meshes
			dest.objs = cloneObjArray src.objs
			)
		dest
		)

	fn pushUndo tag = (
		if gFML != undefined do (
			append _undoStack (cloneFML gFML)
			format "UNDO push (%): depth=%\n" tag _undoStack.count
			)
		)

	fn popUndo = (
		local ok = false
		if _undoStack.count > 0 do (
			gFML = _undoStack[_undoStack.count]
			deleteItem _undoStack _undoStack.count
			format "UNDO pop: depth=%\n" _undoStack.count
			ok = true
			)
		ok
		)

	fn rebuildMatList = (
		if gFML != undefined then (
			lbMats.items = for m in gFML.material_name collect m.name
			) else (lbMats.items=#())
		)

	fn rebuildTexList = (
		if gFML != undefined then (
		lbTex.items = for t in gFML.texture_name collect t.texture_name
			) else (lbTex.items=#())
		)

	fn rebuildTexDDL = (
		if gFML != undefined then (
			local texNames = #("-- none --")
			for t in gFML.texture_name do (
				append texNames t.texture_name
				)
			ddlTex.items = texNames
			) else (ddlTex.items=#("-- none --"))
		ddlTex.selection=1
		)

	fn rebuildObjList = (
		if gFML != undefined then (
			lbObjs.items = for o in gFML.objs collect o.name
			) else (lbObjs.items=#())
		)

	fn showMaterial idx = (
		if gFML != undefined and idx >= 1 and idx <= gFML.material_name.count do (
			local u = gFML.material_name[idx].unk08
			cpAmb.color = color u[2] u[3] u[4]
			cpDif.color = color u[5] u[6] u[7]
			spnSpecLvl.value = u[1]
			cpSpe.color = color u[8] u[9] u[10]
			cpIll.color = color u[12] u[13] u[14]
			edtName.text = gFML.material_name[idx].name
			local ti = u[11] + 2 -- 0-based, -1=none ? +2 for ddl
			if ti < 1 do ti=1
			if ti > ddlTex.items.count do ti=1
			ddlTex.selection = ti
			)
		)

	fn showMeshes objIdx = (
		lbMeshes.items = #()
		if gFML != undefined and objIdx >= 1 and objIdx <= gFML.objs.count do (
			local meshStart = 1
			local i=1
			while i < objIdx do (
				meshStart += gFML.objs[i].num_meshes
				i += 1
				)
			local numMeshes = gFML.objs[objIdx].num_meshes
			local meshEnd = meshStart + numMeshes - 1
			if meshEnd >= meshStart do (
				local items = #()
				i = 1
				while i <= numMeshes do (
					local mIdx = meshStart + i - 1
					local matIdx = gFML.meshes[mIdx].index + 1 -- 1-based for check
					local matName = if matIdx >= 1 and matIdx <= gFML.material_name.count then gFML.material_name[matIdx].name else "None"
					append items ("#" + i as string + " - Mat: " + matName)
					i += 1
					)
				lbMeshes.items = items
				)
			)
		)

	fn adjustMeshIndicesAfterMatDelete delIdx = (
		if gFML != undefined do (
			local i=1
			while i <= gFML.meshes.count do (
				if gFML.meshes[i].index == delIdx then gFML.meshes[i].index = -1
				else if gFML.meshes[i].index > delIdx then gFML.meshes[i].index -= 1
				i += 1
				)
			)
		)

	fn adjustMatTexIndicesAfterTexDelete delIdx = (
		if gFML != undefined do (
			local i=1
			while i <= gFML.material_name.count do (
				local u = gFML.material_name[i].unk08
				if u[11] == delIdx then u[11] = -1
				else if u[11] > delIdx then u[11] -= 1
				i += 1
				)
			)
		)

	on btnLoad pressed do (
		local f = getOpenFileName caption:"Open FML" types:"FML (*.fml)|*.fml|"
		if f != undefined do (
			gFML = fml_t()
			local fh = try(fopen f "rb")catch(undefined)
			if fh != undefined do (
				gFML.read fh
				fclose fh
				rebuildMatList()
				rebuildTexDDL()
				rebuildTexList()
				rebuildObjList()
				messageBox "FML loaded."
				)
			)
		)

	on btnSave pressed do (
		if gFML != undefined do (
			local f = getSaveFileName caption:"Save FML" types:"FML (*.fml)|*.fml|"
			if f != undefined do (
				gFML.write f
				messageBox "FML saved."
				)
			)
		)

	on lbMats selected sel do (
		showMaterial sel
		)

	on btnCopy pressed do (
		local sels = lbMats.selection as array
		if sels.count > 0 do _matClipboard = sels
		)

	on btnPaste pressed do (
		if _matClipboard.count > 0 and gFML != undefined do (
			local dsts = lbMats.selection as array
			if dsts.count > 0 do (
				pushUndo "paste"
				local srcIdx = _matClipboard[1]
				if srcIdx >= 1 and srcIdx <= gFML.material_name.count do (
					local srcMat = gFML.material_name[srcIdx]
					local i=1
					while i <= dsts.count do (
						local dstIdx = dsts[i]
						if dstIdx >= 1 and dstIdx <= gFML.material_name.count do (
							gFML.material_name[dstIdx].name = srcMat.name
							gFML.material_name[dstIdx].unk08 = copy srcMat.unk08 #nomap
							)
						i += 1
						)
					rebuildMatList()
					)
				)
			)
		)

	on btnAuto pressed do (
		if gFML != undefined do (
			pushUndo "rename"
			local seen = #()
			local i=1
			while i <= gFML.material_name.count do (
				local nm = gFML.material_name[i].name
				local base = nm
				local n = 1
				local found = false
				local j=1
				while j <= seen.count do (
					if seen[j] == nm do found = true
					j += 1
					)
				while found do (
					n += 1
					nm = base + "_" + n as string
					found = false
					j=1
					while j <= seen.count do (
						if seen[j] == nm do found = true
						j += 1
						)
					)
				gFML.material_name[i].name = nm
				append seen nm
				i += 1
				)
			rebuildMatList()
			)
		)

	on btnUndo pressed do (
		if popUndo() do (
			rebuildMatList()
			rebuildTexList()
			rebuildTexDDL()
			rebuildObjList()
			if lbObjs.selection > 0 do showMeshes lbObjs.selection
			if lbMats.selection > 0 do showMaterial lbMats.selection
			if lbTex.selection > 0 do (
				edtTexName.text = gFML.texture_name[lbTex.selection].texture_name
				edtFileName.text = gFML.texture_name[lbTex.selection].material_name
				)
			)
		)

	on btnApply pressed do (
		local sels = lbMats.selection as array
		if sels.count > 0 and gFML != undefined do (
			pushUndo "apply"
			local a = cpAmb.color
			local d = cpDif.color
			local s = cpSpe.color
			local e = cpIll.color
			local lvl = spnSpecLvl.value
			local newName = edtName.text
			local texIdx = ddlTex.selection - 2
			local i=1
			while i <= sels.count do (
				local idx = sels[i]
				if idx >= 1 and idx <= gFML.material_name.count do (
					local u = gFML.material_name[idx].unk08
					u[2] = a.r; u[3] = a.g; u[4] = a.b
					u[5] = d.r; u[6] = d.g; u[7] = d.b
					u[1] = lvl
					u[8] = s.r; u[9] = s.g; u[10] = s.b
					u[12] = e.r; u[13] = e.g; u[14] = e.b
					if texIdx >= -1 do u[11] = texIdx
					gFML.material_name[idx].unk08 = u
					if newName != "" do gFML.material_name[idx].name = newName
					)
				i += 1
				)
			rebuildMatList()
			)
		)

	on btnAddMat pressed do (
		if gFML != undefined do (
			pushUndo "add mat"
			local defaultUnk = #(25, 0,0,0, 255,255,255, 255,255,255, -1, 0,0,0)
			append gFML.material_name (fmlMaterialName_t name:"new_mat" unk08:defaultUnk)
			rebuildMatList()
			)
		)

	on btnDelMat pressed do (
		local sel = lbMats.selection
		if sel > 0 and gFML != undefined do (
			pushUndo "del mat"
			local delIdx = sel - 1
			deleteItem gFML.material_name sel
			adjustMeshIndicesAfterMatDelete delIdx
			rebuildMatList()
			)
		)

	on lbTex selected sel do (
		if gFML != undefined and sel >= 1 and sel <= gFML.texture_name.count do (
			edtTexName.text = gFML.texture_name[sel].texture_name
			edtFileName.text = gFML.texture_name[sel].material_name
			)
		)

	on btnAddTex pressed do (
		if gFML != undefined do (
			pushUndo "add tex"
			append gFML.texture_name (fmlTextureName_t texture_name:"new_tex" material_name:"new_file")
			rebuildTexList()
			rebuildTexDDL()
			)
		)

	on btnDelTex pressed do (
		local sel = lbTex.selection
		if sel > 0 and gFML != undefined do (
			pushUndo "del tex"
			local delIdx = sel - 1
			deleteItem gFML.texture_name sel
			adjustMatTexIndicesAfterTexDelete delIdx
			rebuildTexList()
			rebuildTexDDL()
			)
		)

	on btnApplyTex pressed do (
		local sel = lbTex.selection
		if sel > 0 and gFML != undefined do (
			pushUndo "apply tex"
			gFML.texture_name[sel].texture_name = edtTexName.text
			gFML.texture_name[sel].material_name = edtFileName.text
			rebuildTexList()
			rebuildTexDDL()
			)
		)

	on lbObjs selected sel do (
		showMeshes sel
		)

	on btnAssign pressed do (
		local objIdx = lbObjs.selection
		local matSel = lbMats.selection
		local meshSels = lbMeshes.selection as array
		if objIdx > 0 and matSel > 0 and meshSels.count > 0 and gFML != undefined do (
			pushUndo "assign"
			local newMatIdx = matSel - 1
			local meshStart = 1
			local i=1
			while i < objIdx do (
				meshStart += gFML.objs[i].num_meshes
				i += 1
				)
			i=1
			while i <= meshSels.count do (
				local sel = meshSels[i]
				local meshIdx = meshStart + sel - 1
				if meshIdx >= 1 and meshIdx <= gFML.meshes.count do (
					gFML.meshes[meshIdx].index = newMatIdx
					)
				i += 1
				)
			showMeshes objIdx
			)
		)

	)
createDialog raw2

/*
raw2.read (
	"C:\\Users\\Corey\\Downloads\\RAW2\\X0002.fml"
-- 	"C:\\Users\\Corey\\Downloads\\RAW2\\Hands\\HandR\\M2105.fml"
-- 	"C:\\Users\\Corey\\Downloads\\RAW2\\Character\\ArmR\\W1339.fml"
	"G:\\RumbleRosesXX\\RAW2\\X0001.fml"
-- 	"G:\\RumbleRosesXX\\RAW2\\X0001.fml_resave.fml"
	"G:\\RumbleRosesXX\\RAW2\\WRITE_TEST.fml"
-- 	GetOpenFileName caption:"Open Uasset" types: "model (*.fml)|*.fml|All files (*.*)|*.*|"
	)



raw2.write (
	"G:\\RumbleRosesXX\\RAW2\\WRITE_TEST.fml"
	)
*/