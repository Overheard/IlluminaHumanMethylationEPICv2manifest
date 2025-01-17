library(vroom)
library(minfi)
library(illuminaio)
library(devtools)
#library(minfiData)
#library(minfiDataEPIC)

#data(MsetEx)
#data(MsetEPIC)

#m450k <- getManifest(MsetEx)
#me <- getManifest(MsetEPIC)
#"cg12981137"
#"cg12434587"

#type1 <- getProbeInfo(m450k,c("I"))
#type1[which(type1$Name=="cg12981137"),]
#type1[which(type1$Name=="cg12434587"),]

#type1 <- getProbeInfo(me,c("I"))
#type1[which(type1$Name=="cg12981137"),]
#type1[which(type1$Name=="cg12434587"),]

rm(list=ls())
gc()

file <- "EPIC-8v2-0_EA.csv"

e1 <- vroom(file.path("Z:/Gagri_Cancer-Epigenetics/Projects/EPIC_V2/",file))

control.line <- grep("Controls",e1$Illumina)+1
assay.line <- grep("\\[Assay",e1$Illumina)+1

rm(e1)
gc()

manifest <- vroom(file.path("Z:/Gagri_Cancer-Epigenetics/Projects/EPIC_V2/",file),skip=assay.line,n_max =control.line-assay.line-2) 

#manifest[which(manifest$Name=="cg12981137"),"AlleleA_ProbeSeq"]
#manifest[which(manifest$Name=="cg12981137"),"Infinium_Design"]
#manifest[which(manifest$Name=="cg12981137"),"IlmnID"]

#manifest[which(manifest$Name=="cg12434587"),"AlleleA_ProbeSeq"]
#manifest[which(manifest$Name=="cg12434587"),"IlmnID"]

manifest <- manifest[-which(manifest$IlmnID %in% c("cg12434587_BO11","cg12981137_BO11","cg12981137_TC21","cg12981137_BC21")),]


manifest$AddressA_ID <- gsub("^0*", "", manifest$AddressA_ID)
manifest$AddressB_ID <- gsub("^0*", "", manifest$AddressB_ID)

manifest$AddressA_ID[is.na(manifest$AddressA_ID)] <- ""
manifest$AddressB_ID[is.na(manifest$AddressB_ID)] <- ""

TypeI <- manifest[manifest$Infinium_Design_Type == "I",
                  c("IlmnID", "AddressA_ID", "AddressB_ID", "Color_Channel", "Next_Base",
                    "AlleleA_ProbeSeq", "AlleleB_ProbeSeq")]

names(TypeI)[c(1,2, 3, 4, 5, 6, 7)] <- c("Name", "AddressA", "AddressB", "Color", "NextBase", "ProbeSeqA", "ProbeSeqB")

TypeI <- as(TypeI, "DataFrame")
TypeI$ProbeSeqA <- DNAStringSet(TypeI$ProbeSeqA)
TypeI$ProbeSeqB <- DNAStringSet(TypeI$ProbeSeqB)
TypeI$NextBase <- DNAStringSet(TypeI$NextBase)
TypeI$nCpG <- as.integer(
  oligonucleotideFrequency(TypeI$ProbeSeqB, width = 2)[, "CG"] - 1L)
TypeI$nCpG[TypeI$nCpG < 0] <- 0L
TypeSnpI <- TypeI[grep("^rs", TypeI$Name), ]
TypeI <- TypeI[-grep("^rs", TypeI$Name), ]
TypeI <- TypeI[-grep("^nv", TypeI$Name), ]

TypeII <- manifest[
  manifest$Infinium_Design_Type == "II",
  c("IlmnID", "AddressA_ID", "AlleleA_ProbeSeq")]
names(TypeII)[c(1,2,3)] <- c("Name","AddressA", "ProbeSeqA")
TypeII <- as(TypeII, "DataFrame")
TypeII$ProbeSeqA <- DNAStringSet(TypeII$ProbeSeqA)
TypeII$nCpG <- as.integer(letterFrequency(TypeII$ProbeSeqA, letters = "R"))
TypeII$nCpG[TypeII$nCpG < 0] <- 0L
TypeSnpII <- TypeII[grep("^rs", TypeII$Name), ]
TypeII <- TypeII[-grep("^rs", TypeII$Name), ]
TypeII <- TypeII[-grep("^nv", TypeII$Name), ]

controls <- read.table(
  file = file.path("Z:/Gagri_Cancer-Epigenetics/Projects/EPIC_V2/",file),
  skip = control.line,
  sep = ",",
  comment.char = "",
  quote = "",
  colClasses = c(rep("character", 5)))[, 1:5]

TypeControl <- controls[, 1:4]
names(TypeControl) <- c("Address", "Type", "Color", "ExtendedType")
TypeControl <- as(TypeControl, "DataFrame")


maniTmp <- list(
  manifestList = list(
    TypeI = TypeI,
    TypeII = TypeII,
    TypeControl = TypeControl,
    TypeSnpI = TypeSnpI,
    TypeSnpII = TypeSnpII),
  manifest = manifest,
  controls = controls)


# checks
manifest <- maniTmp$manifest

epic <- readIDAT("Z:/Gagri_Cancer-Epigenetics-Data/EPIC_Level_1/EPIC_V2_Trial/V2/idats/206909630026_R01C01_Grn.idat")

address.epic <- as.character(epic$MidBlock)

dropCpGs <- manifest$IlmnID[manifest$AddressB_ID != "" & !manifest$AddressB_ID %in% address.epic]
table(substr(dropCpGs, 1,2))

dropCpGs <- manifest$IlmnID[manifest$AddressA_ID != "" & !manifest$AddressA_ID %in% address.epic]
table(substr(dropCpGs, 1,2))

## Controls ok
maniTmp$controls[!maniTmp$manifestList$TypeControl$Address %in% address.epic,]

## Manifest package
maniList <- maniTmp$manifestList

IlluminaHumanMethylationEPICv2manifest <- IlluminaMethylationManifest(TypeI = maniList$TypeI,
                                                              TypeII = maniList$TypeII,
                                                              TypeControl = maniList$TypeControl,
                                                              TypeSnpI = maniList$TypeSnpI,
                                                              TypeSnpII = maniList$TypeSnpII,
                                                              annotation = "IlluminaHumanMethylationEPICv2")

use_data(IlluminaHumanMethylationEPICv2manifest, internal=TRUE, overwrite = T)
