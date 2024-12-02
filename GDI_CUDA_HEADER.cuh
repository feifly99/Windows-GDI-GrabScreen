#ifndef __GDI_GRAB_SCREEN__
#define __GDI_GRAB_SCREEN__

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <Windows.h>
#include <time.h>

#ifndef YES
#define YES TRUE
#endif

#ifndef NO
#define NO FALSE
#endif

#ifndef IN
#define IN
#endif

#ifndef OUT
#define OUT
#endif

#ifndef IN_OUT
#define IN_OUT
#endif

#ifndef IN_OPT
#define IN_OPT
#endif

#ifndef OUT_HOST_PTR
#define OUT_HOST_PTR
#endif

#define OUT_PTR OUT_HOST_PTR

#ifndef OUT_DEVICE_PTR
#define OUT_DEVICE_PTR
#endif

#define MAX_DIMENSION_SIZE 3

#define QAQ printf("\n")

#define ckFloatValueOnly(sen) printf("%.3f\n", (float)(sen))
#define ckFloatValueWithExplain(sen) printf("%s -> %.3f\n", (const char*)#sen, (float)(sen))

#define ckSizeTValueOnly(sen) printf("%zu\n", (SIZE_T)(sen))
#define ckSizeTValueWithExplain(sen) printf("%s -> %zu\n", (const char*)#sen, (SIZE_T)(sen))

#define IN_CLEAR_OUT
#define SHOW_LOG

#ifndef ASSERT
#define ASSERT(p) (p) ? 1:exit(0xFFF);
#endif

#ifndef NANO_TYPE
#define NANO_TYPE UCHAR
#endif

#pragma warning(disable:6387)
#pragma warning(disable:6385)
#pragma warning(disable:6011)
#pragma warning(disable:28183)

#define fors(times, sentence) \
do\
{\
	for(size_t j = 0; j < (times); j++)\
	{\
		sentence\
	}\
}while(0)

#define forss(times1, times2, sentenceInner, sentenceOuter) \
do\
{\
	for(size_t j = 0; j < (times1); j++)\
	{\
		for(size_t i = 0; i < (times2); i++)\
		{\
			sentenceInner\
		}\
		sentenceOuter\
	}\
}while(0)

typedef struct _Point
{
    int x;
    int y;
}Point, * PPoint;

typedef struct _img
{
    PBITMAPFILEHEADER filePointer;
    PBITMAPINFOHEADER infoPointer;
    PVOID pixelPointer;
}IMG, * PIMG;

typedef struct _pixelRGB
{
    UCHAR R;
    UCHAR G;
    UCHAR B;
}pxlRGB, * ppxlRGB;

typedef struct _RGB_TENSOR
{
    size_t width;
    size_t height;
    size_t depth;
    UCHAR*** RGBtensor;
}RGB_TENSOR, * PRGB_TENSOR;

typedef enum _myCudaDataFlag
{
	CUDA_DATA_FLAG_$_VECTOR_$ = 1,
	CUDA_DATA_FLAG_$_MATRIX_$ = 2,
	CUDA_DATA_FLAG_$_TENSOR_$ = 3,
}myCudaDataFlag;

typedef enum _myCudaCalculateFlag
{
	CUDA_CAU_TYPE_$_ADD_$ = 1,
	CUDA_CAU_TYPE_$_MULTIPLE_$ = 2,
}myCudaCalculateFlag;

typedef enum _DATA_GENERATE_TYPE
{
	GENERATE_RANDOM = 1,
	GENERATE_ALL_ZERO = 2,
	GENERATE_ALL_ONE = 3,
	GENERATE_TEST = 4,
	GENERATE_EXISTING = 5
}DATA_GENERATE_TYPE;

typedef struct _vectorType
{
	size_t size;
	float* vector;
	size_t objectReference;
}V, * PV;

typedef struct _matrixType
{
	size_t rowSize;
	size_t colSize;
	float** matrix;
	size_t objectReference;
}M, * PM;

typedef struct _tensorType
{
	size_t lenSize;
	size_t widSize;
	size_t higSize;
	float*** tensor;
	size_t objectReference;
}T, * PT;

typedef struct _dataSet
{
	union _dataType
	{
		struct _vectorType
		{
			size_t size;
			float* vector;
			size_t objectReference;
		}Vector;

		struct _matrixType
		{
			size_t rowSize;
			size_t colSize;
			float** matrix;
			size_t objectReference;
		}Matrix;

		struct _tensorType
		{
			size_t lenSize;
			size_t widSize;
			size_t higSize;
			float*** tensor;
			size_t objectReference;
		}Tensor;

	}dataType;

	myCudaDataFlag dataFlag;

}DATA_SET, * PDATA_SET;

void ExFreeMem(
    PVOID* mem
);

pxlRGB getPixelRGB_byRGBPointer(
    IN PVOID firstRGBPointer
);

void echo(
    IN SHOW_LOG WCHAR* str
);

void initializeInfoHeader(
    IN BITMAP bmpScreen,
    OUT BITMAPINFOHEADER* bi
);

void initializeFileHeader(
    OUT PBITMAPFILEHEADER imgFileHeader,
    IN DWORD sizeHeaderAndInfo,
    IN DWORD wholeSize,
    IN WORD imgHeadMarkCode
);

void initializePixelHeader(
    OUT_PTR PVOID* imgPixelHeader,
    IN LONG imgPixelSize,
    IN HDC nakedScreenImage,
    IN HBITMAP hiddenImageInstance,
    IN BITMAP img,
    IN BITMAPINFO* imgInfoHeader
);

void createImageFile(
    IN WCHAR* w_filePath,
    OUT HANDLE* hFile
);

SIZE_T getTotalBitMapSize(
    IN DWORD dwBmpSize
);

LONG getBmpSize(
    IN BITMAP bmpScreen,
    IN BITMAPINFOHEADER bi
);

void saveImg2Disk(
    OUT HANDLE* hFile,
    CONST WCHAR* fatherLocWithNoMark,
    CONST WCHAR* imgName,
    IN PBITMAPFILEHEADER imgFileHeader,
    IN PBITMAPINFOHEADER imgInfoHeader,
    IN PVOID imgPixelHeader,
    IN DWORD wholeSize
);

void transScreenDC2Img(
    IN HDC screenDC,
    OUT BITMAP* img,
    IN Point lt,
    IN Point rb,
    OUT_PTR HDC** _hiddenImgCode,
    OUT_PTR HBITMAP** _hiddenImageInstance
);

PIMG makeImg(
    IN BITMAP img,
    IN_CLEAR_OUT HDC* screenDC,
    IN_CLEAR_OUT HDC** memDC,
    IN_CLEAR_OUT HBITMAP** memImg,
    IN BOOLEAN isSaveToDisk,
    IN_OPT CONST WCHAR* name
);

void makeImgRgbTensor(
    IN_CLEAR_OUT PIMG* img,
    PRGB_TENSOR* tensor
);

OUT_HOST_PTR PDATA_SET makeDataSet(
	IN myCudaDataFlag inputDataFlag,
	IN DATA_GENERATE_TYPE dataGenerateType,
	IN_OUT SIZE_T(*dimensions)[MAX_DIMENSION_SIZE],
	IN SIZE_T alignmentValue,
	IN_OPT PVOID existData
);

void checkDataSet(
	IN PDATA_SET dataSet
);

void makeCudaFriendlyData(
	IN PDATA_SET hostDataSet,
	OUT_HOST_PTR float** deviceDataSet
);

void safetyCheck(
	IN PDATA_SET dataSet1,
	IN PDATA_SET dataSet2,
	IN myCudaDataFlag dataFlag,
	IN myCudaCalculateFlag calculateFlag
);

void ExFreeDataSet(
	IN_OUT PDATA_SET* dataSet
);

void cudaExFreeMem(
	IN_OUT PVOID* _GPU_mem
);

void callCuda(
	IN PDATA_SET data1,
	IN PDATA_SET data2,
	IN myCudaDataFlag dataFlag,
	IN myCudaCalculateFlag calculateFlag,
	OUT_HOST_PTR float** result
);

void ExFreeRgbTensor(
	IN_CLEAR_OUT PRGB_TENSOR* tensor
);

void playRgbTensor(
	IN_OUT PRGB_TENSOR* rgbTensor
);

void transRgbTensor2ImgOnDisk(
	IN_CLEAR_OUT PRGB_TENSOR* rgbTensor,
	IN CONST WCHAR* imgName
);

#endif