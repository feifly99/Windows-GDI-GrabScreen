#include "GDI_CUDA_HEADER.cuh"

void ExFreeMem(
    PVOID* mem
)
{
    if (*mem == NULL)
    {
        printf("空指针传入.\n");
        return;
    }
    free(*mem);
    *mem = NULL;
    return;
}

pxlRGB getPixelRGB_byRGBPointer(
    IN PVOID firstRGBPointer
)
{
    pxlRGB ret = { 0 };
    ret.R = *(UCHAR*)((ULONG64)firstRGBPointer + 2);
    ret.G = *(UCHAR*)((ULONG64)firstRGBPointer + 1);
    ret.B = *(UCHAR*)((ULONG64)firstRGBPointer + 0);
    return ret;
}

void echo(
    IN SHOW_LOG WCHAR* str
)
{
    MessageBoxW(NULL, str, NULL, MB_OK);
}

void initializeInfoHeader(
    IN BITMAP bmpScreen,
    OUT BITMAPINFOHEADER* bi
)
{
    (*bi).biSize = sizeof(BITMAPINFOHEADER);
    (*bi).biWidth = bmpScreen.bmWidth;
    (*bi).biHeight = bmpScreen.bmHeight;
    (*bi).biPlanes = 1;
    (*bi).biBitCount = 32;
    (*bi).biCompression = BI_RGB;
    (*bi).biSizeImage = 0;
    (*bi).biXPelsPerMeter = 0;
    (*bi).biYPelsPerMeter = 0;
    (*bi).biClrUsed = 0;
    (*bi).biClrImportant = 0;
    return;
}

void initializeFileHeader(
    OUT PBITMAPFILEHEADER imgFileHeader,
    IN DWORD sizeHeaderAndInfo,
    IN DWORD wholeSize,
    IN WORD imgHeadMarkCode
)
{
    imgFileHeader->bfOffBits = sizeHeaderAndInfo;
    imgFileHeader->bfSize = wholeSize;
    imgFileHeader->bfType = 0x4D42;
    return;
}

void initializePixelHeader(
    OUT_PTR PVOID* imgPixelHeader,
    IN LONG imgPixelSize,
    IN HDC nakedScreenImage,
    IN HBITMAP hiddenImageInstance,
    IN BITMAP img,
    IN BITMAPINFO* imgInfoHeader
)
{
    *imgPixelHeader = malloc((SIZE_T)imgPixelSize);
    GetDIBits(
        nakedScreenImage,
        hiddenImageInstance,
        0,
        (UINT)img.bmHeight,
        *imgPixelHeader,
        imgInfoHeader,
        DIB_RGB_COLORS
    );
}

void createImageFile(
    IN WCHAR* w_filePath,
    OUT HANDLE* hFile
)
{
    *hFile = CreateFileW(
        w_filePath,
        GENERIC_WRITE,
        0,
        NULL,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );
}

SIZE_T getTotalBitMapSize(
    IN DWORD dwBmpSize
)
{
    return (SIZE_T)dwBmpSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
}

LONG getBmpSize(
    IN BITMAP bmpScreen,
    IN BITMAPINFOHEADER bi
)
{
    return ((bmpScreen.bmWidth * bi.biBitCount + 31) / 32) * 4 * bmpScreen.bmHeight;
}

void saveImg2Disk(
    OUT HANDLE* hFile,
    CONST WCHAR* fatherLocWithNoMark,
    CONST WCHAR* imgName,
    IN PBITMAPFILEHEADER imgFileHeader,
    IN PBITMAPINFOHEADER imgInfoHeader,
    IN PVOID imgPixelHeader,
    IN DWORD wholeSize
)
{
    WCHAR FilePath[MAX_PATH];
    wsprintfW(FilePath, L"%s\\%s.png", fatherLocWithNoMark, imgName);

    createImageFile(FilePath, hFile);
    WriteFile(*hFile, (LPSTR)imgFileHeader, sizeof(BITMAPFILEHEADER), NULL, NULL);
    WriteFile(*hFile, (LPSTR)imgInfoHeader, sizeof(BITMAPINFOHEADER), NULL, NULL);
    WriteFile(*hFile, (LPSTR)imgPixelHeader, wholeSize, NULL, NULL);
    return;
}

void transScreenDC2Img(
    IN HDC screenDC,
    OUT BITMAP* img,
    IN Point lt,
    IN Point rb,
    OUT_PTR HDC** _hiddenImgCode,
    OUT_PTR HBITMAP** _hiddenImageInstance
)
{
    int w = rb.x - lt.x;
    int h = rb.y - lt.y;
    *_hiddenImgCode = (HDC*)malloc(sizeof(HDC));
    *_hiddenImageInstance = (HBITMAP*)malloc(sizeof(HBITMAP));
    **_hiddenImgCode = CreateCompatibleDC(screenDC);
    **_hiddenImageInstance = CreateCompatibleBitmap(screenDC, w, h);

    SelectObject(**_hiddenImgCode, **_hiddenImageInstance);
    BitBlt(
        **_hiddenImgCode,
        0, 0,
        w, h,
        screenDC,
        lt.x, lt.y,
        SRCCOPY
    );
    GetObjectW(**_hiddenImageInstance, sizeof(BITMAP), img);
    return;
}

PIMG makeImg(
    IN BITMAP img,
    IN_CLEAR_OUT HDC* screenDC,
    IN_CLEAR_OUT HDC** memDC,
    IN_CLEAR_OUT HBITMAP** memImg,
    IN BOOLEAN isSaveToDisk,
    IN_OPT CONST WCHAR* name
)
{
    PIMG ret = (PIMG)malloc(sizeof(IMG));

    PBITMAPINFOHEADER imgInfoHeaderPointer = (PBITMAPINFOHEADER)malloc(sizeof(BITMAPINFOHEADER));
    PBITMAPFILEHEADER imgFileHeaderPointer = (PBITMAPFILEHEADER)malloc(sizeof(BITMAPFILEHEADER));
    PVOID imgPixelHeader = NULL;

    initializeInfoHeader(img, imgInfoHeaderPointer);

    LONG imgPixelSize = getBmpSize(img, *imgInfoHeaderPointer);
    initializePixelHeader(
        &imgPixelHeader,
        imgPixelSize,
        *screenDC,
        **memImg,
        img,
        (BITMAPINFO*)imgInfoHeaderPointer
    );

    initializeFileHeader(
        imgFileHeaderPointer,
        (DWORD)sizeof(BITMAPFILEHEADER) + (DWORD)sizeof(BITMAPINFOHEADER),
        imgPixelSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER),
        0x4D42
    );

    if (isSaveToDisk && name)
    {
        HANDLE hFile = NULL;
        saveImg2Disk(
            &hFile,
            L"E:\\desk",
            name,
            imgFileHeaderPointer,
            imgInfoHeaderPointer,
            imgPixelHeader,
            imgPixelSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER)
        );
        CloseHandle(hFile);
    }
    else
    {
        printf("isSaveToDisk && name == 0, 检查输入.\n");
        exit(0xFFFFFFCF);
    }

    ret->filePointer = imgFileHeaderPointer;
    ret->infoPointer = imgInfoHeaderPointer;
    ret->pixelPointer = imgPixelHeader;

    DeleteObject(**memImg);
    ExFreeMem((PVOID*)&(*memImg));
    DeleteObject(**memDC);
    ExFreeMem((PVOID*)&(*memDC));
    ReleaseDC(NULL, *screenDC);
    return ret;
}

void makeImgRgbTensor(
    IN_CLEAR_OUT PIMG* img,
    PRGB_TENSOR* tensor
)
{
    if (*tensor != NULL)
    {
        printf("已经有值.\n");
        exit(0xEEFFEE);
    }
    *tensor = (PRGB_TENSOR)malloc(sizeof(RGB_TENSOR));
    (*tensor)->width = (*img)->infoPointer->biWidth;
    (*tensor)->height = (*img)->infoPointer->biHeight;
    (*tensor)->depth = 3;
    (*tensor)->RGBtensor = (UCHAR***)malloc((*tensor)->depth * sizeof(UCHAR**));
    fors(
        (*tensor)->depth,
        ((*tensor)->RGBtensor)[j] = (UCHAR**)malloc((*tensor)->height * sizeof(UCHAR*));
    );
    forss(
        (*tensor)->depth, (*tensor)->height,
        ((*tensor)->RGBtensor)[j][i] = (UCHAR*)malloc((*tensor)->width * sizeof(UCHAR));,
    );
    ULONG64 headerPixelPointer = (ULONG64)((*img)->pixelPointer) + (*tensor)->width * (*tensor)->height * ((*tensor)->depth + 1) - 4;
    forss(
		(*tensor)->height, (*tensor)->width,
        ((*tensor)->RGBtensor)[0][j][(*tensor)->width - i - 1] = *(UCHAR*)(headerPixelPointer + 2); //R
		((*tensor)->RGBtensor)[1][j][(*tensor)->width - i - 1] = *(UCHAR*)(headerPixelPointer + 1); //G
		((*tensor)->RGBtensor)[2][j][(*tensor)->width - i - 1] = *(UCHAR*)(headerPixelPointer + 0); //B
		headerPixelPointer -= 4; ,
    );
    ExFreeMem((PVOID*)&((*img)->filePointer));
    ExFreeMem((PVOID*)&((*img)->infoPointer));
    ExFreeMem((PVOID*)&((*img)->pixelPointer));
    ExFreeMem((PVOID*)&((*img)));
    return;
}

static void makeCudaFriendlyDimensionAligned(
	IN_OUT SIZE_T (*dimensions)[MAX_DIMENSION_SIZE],
	IN SIZE_T alignment
)
{
	if ((*dimensions) == NULL)
	{
		printf("不合法的维数输入，已驳回.\n");
		exit(0xA000);
	}

	fors(
		MAX_DIMENSION_SIZE,
		(*dimensions)[j] = ((*dimensions)[j] + alignment - 1) & ~(alignment - 1);
	);
	return;
}

OUT_HOST_PTR PDATA_SET makeDataSet(
	IN myCudaDataFlag inputDataFlag,
	IN DATA_GENERATE_TYPE dataGenerateType,
	IN_OUT SIZE_T(*dimensions)[MAX_DIMENSION_SIZE],
	IN SIZE_T alignmentValue,
	IN_OPT PVOID existData
)
{
	SIZE_T dimension0 = (*dimensions)[0];
	SIZE_T dimension1 = (*dimensions)[1];
	SIZE_T dimension2 = (*dimensions)[2];
	makeCudaFriendlyDimensionAligned(dimensions, alignmentValue);
	PDATA_SET ret = (PDATA_SET)malloc(sizeof(DATA_SET));
	ret->dataFlag = inputDataFlag;
	if (ret->dataFlag == CUDA_DATA_FLAG_$_VECTOR_$)
	{
		if (dimension1 != 0 || dimension2 != 0)
		{
			printf("输入维数和数据类型可能不符，已驳回.\n");
			free(ret);
			ret = NULL;
			exit(0xFA00);
		}

		ret->dataType.Vector.size = (*dimensions)[0];

		ret->dataType.Vector.vector = (float*)malloc((*dimensions)[0] * sizeof(float));
		RtlZeroMemory(ret->dataType.Vector.vector, (*dimensions)[0]);

		ret->dataType.Vector.objectReference = 1;

		if (dataGenerateType == GENERATE_RANDOM)
		{
			fors(
				ret->dataType.Vector.size,
				ret->dataType.Vector.vector[j] = (float)(rand() % 20 + 1);
				);
		}
		else if (dataGenerateType == GENERATE_ALL_ZERO)
		{
			fors(
				ret->dataType.Vector.size,
				ret->dataType.Vector.vector[j] = 0.0f;
				);
		}
		else if (dataGenerateType == GENERATE_ALL_ONE)
		{
			fors(
				ret->dataType.Vector.size,
				ret->dataType.Vector.vector[j] = 1.0f;
				);
		}
		else if (dataGenerateType == GENERATE_TEST)
		{
			fors(
				ret->dataType.Vector.size,
				ret->dataType.Vector.vector[j] = (float)(j);
				);
		}
		else if (dataGenerateType == GENERATE_EXISTING)
		{
			if (existData == NULL)
			{
				printf("选择了已存在数据进行复制但是输入指针为空，已驳回.\n");
				free(ret->dataType.Vector.vector);
				ret->dataType.Vector.vector = NULL;
				free(ret);
				ret = NULL;
				exit(0xFAC0);
			}
			else
			{
				if (dimension0 <= (*dimensions)[0])
				{
					fors(
						ret->dataType.Vector.size,
						ret->dataType.Vector.vector[j] = ((float*)existData)[j];
					);
				}
			}
		}
		else
		{
			printf("生成类型不符，已驳回.\n");
			free(ret->dataType.Vector.vector);
			ret->dataType.Vector.vector = NULL;
			free(ret);
			ret = NULL;
			exit(0xFAF0);
		}
	}
	else if (ret->dataFlag == CUDA_DATA_FLAG_$_MATRIX_$)
	{
		if (dimension2 != 0)
		{
			printf("输入维数和数据类型不符，已驳回.\n");
			free(ret);
			ret = NULL;
			exit(0xFA00);
		}

		ret->dataType.Matrix.rowSize = (*dimensions)[0];
		ret->dataType.Matrix.colSize = (*dimensions)[1];

		ret->dataType.Matrix.matrix = (float**)malloc((*dimensions)[0] * sizeof(float*));

		fors(
			(*dimensions)[0],
			ret->dataType.Matrix.matrix[j] = (float*)malloc((*dimensions)[1] * sizeof(float));
		);
		forss(
			(*dimensions)[0], (*dimensions)[1],
			ret->dataType.Matrix.matrix[j][i] = 0.0f; ,
			);

		ret->dataType.Matrix.objectReference = 1;

		if (dataGenerateType == GENERATE_RANDOM)
		{
			forss(
				(*dimensions)[0], (*dimensions)[1],
				ret->dataType.Matrix.matrix[j][i] = (float)(rand() % 20 + 1); ,
				);
		}
		else if (dataGenerateType == GENERATE_ALL_ZERO)
		{
			forss(
				(*dimensions)[0], (*dimensions)[1],
				ret->dataType.Matrix.matrix[j][i] = 0.0f; ,
				);
		}
		else if (dataGenerateType == GENERATE_ALL_ONE)
		{
			forss(
				(*dimensions)[0], (*dimensions)[1],
				ret->dataType.Matrix.matrix[j][i] = 1.0f; ,
				);
		}
		else if (dataGenerateType == GENERATE_TEST)
		{
			forss(
				(*dimensions)[0], (*dimensions)[1],
				ret->dataType.Matrix.matrix[j][i] = (float)((float)(j + 1) / (float)20.0); ,
				);
		}
		else if (dataGenerateType == GENERATE_EXISTING)
		{
			if (existData == NULL)
			{
				printf("选择了已存在数据进行复制但是输入指针为空，已驳回.\n");

				fors(
					(*dimensions)[0],
					free(ret->dataType.Matrix.matrix[j]);
				ret->dataType.Matrix.matrix[j] = NULL;
					);
				free(ret->dataType.Matrix.matrix);
				ret->dataType.Matrix.matrix = NULL;
				free(ret);
				ret = NULL;
				exit(0xFAC0);
			}
			else
			{
				if (dimension0 <= (*dimensions)[0] && dimension1 <= (*dimensions)[1])
				{
					forss(
						dimension0, dimension1,
						ret->dataType.Matrix.matrix[j][i] = (float)(((UCHAR**)existData)[j][i]); ,
					);
				}
			}
		}
		else
		{
			printf("生成类型不符，已驳回.\n");
			fors(
				(*dimensions)[0],
				free(ret->dataType.Matrix.matrix[j]);
			ret->dataType.Matrix.matrix[j] = NULL;
				);
			free(ret->dataType.Matrix.matrix);
			ret->dataType.Matrix.matrix = NULL;
			exit(0xFAF0);
		}
	}
	else
	{
		printf("数据类型不符，已驳回.\n");
		free(ret);
		ret = NULL;
		exit(0xC000);
	}
	return ret;
}

void checkDataSet(
	IN PDATA_SET dataSet
)
{
	if (dataSet->dataFlag == 1)
	{
		//vector
		if (!dataSet->dataType.Vector.objectReference)
		{
			printf("对象引用计数为零，可能为空，已驳回.\n");
		}
		printf("数据集: 向量\n");
		printf("向量长度: %zu\n", dataSet->dataType.Vector.size);
		printf("当前引用计数: %zu\n", dataSet->dataType.Vector.objectReference);
		printf("具体数值: \n");
		fors(
			dataSet->dataType.Vector.size,
			printf("%.2f\t", dataSet->dataType.Vector.vector[j]);
		);
		QAQ;
		return;
	}
	else if (dataSet->dataFlag == 2)
	{
		//matrix
		if (!dataSet->dataType.Matrix.objectReference)
		{
			printf("对象引用计数为零，可能为空，已驳回.\n");
		}
		printf("数据集: 矩阵\n");
		printf("矩阵行数: %zu\n", dataSet->dataType.Matrix.rowSize);
		printf("矩阵列数: %zu\n", dataSet->dataType.Matrix.colSize);
		printf("当前引用计数: %zu\n", dataSet->dataType.Matrix.objectReference);
		printf("具体数值: \n");
		forss(
			dataSet->dataType.Matrix.rowSize, dataSet->dataType.Matrix.colSize,
			printf("%.1f\t", dataSet->dataType.Matrix.matrix[j][i]); ,
			QAQ;
		);
	}
	else
	{
		printf("非法数据类型，已驳回.\n");
	}
	return;
}

void makeCudaFriendlyData(
	IN PDATA_SET hostDataSet,
	OUT_HOST_PTR float** deviceDataSet
)
{
	if (hostDataSet->dataFlag == CUDA_DATA_FLAG_$_VECTOR_$)
	{
		//vector
		if (!hostDataSet->dataType.Vector.objectReference)
		{
			printf("对象引用计数为零，可能为空，已驳回.\n");
		}
		*deviceDataSet = (float*)malloc(hostDataSet->dataType.Vector.size * sizeof(float));
		memcpy(*deviceDataSet, hostDataSet->dataType.Vector.vector, hostDataSet->dataType.Vector.size * sizeof(float));
		return;
	}
	else if (hostDataSet->dataFlag == CUDA_DATA_FLAG_$_MATRIX_$)
	{
		//matrix
		if (!hostDataSet->dataType.Matrix.objectReference)
		{
			printf("对象引用计数为零，可能为空，已驳回.\n");
		}
		*deviceDataSet = (float*)malloc(hostDataSet->dataType.Matrix.rowSize * hostDataSet->dataType.Matrix.colSize * sizeof(float));
		for (size_t j = 0; j < hostDataSet->dataType.Matrix.rowSize; j++)
		{
			for (size_t i = 0; i < hostDataSet->dataType.Matrix.colSize; i++)
			{
				(*deviceDataSet)[i + j * hostDataSet->dataType.Matrix.colSize] = hostDataSet->dataType.Matrix.matrix[j][i];
			}
		}
	}
	else
	{
		printf("非法数据类型，已驳回.\n");
	}
	return;
}

void safetyCheck(
	IN PDATA_SET dataSet1,
	IN PDATA_SET dataSet2,
	IN myCudaDataFlag dataFlag,
	IN myCudaCalculateFlag calculateFlag
)
{
	if (dataSet1->dataFlag != dataFlag || dataSet2->dataFlag != dataFlag)
	{
		printf("输入数据集的类型和调用的数据集类型不同，已驳回.\n");
		exit(0xECC0);
	}
	if (dataFlag == CUDA_DATA_FLAG_$_VECTOR_$)
	{
		if (calculateFlag == CUDA_CAU_TYPE_$_ADD_$)
		{
			if (dataSet1->dataType.Vector.size != dataSet2->dataType.Vector.size)
			{
				printf("两个向量的尺寸不同，已驳回.\n");
				exit(0xDCC0);
			}
		}
		else if (calculateFlag == CUDA_CAU_TYPE_$_MULTIPLE_$)
		{
			if (dataSet1->dataType.Vector.size != dataSet2->dataType.Vector.size)
			{
				printf("两个向量的尺寸不同，已驳回.\n");
				exit(0xDCC0);
			}
		}
		else
		{
			printf("调用的计算类型不被支持，已驳回.\n");
			exit(0xDCC0);
		}
	}
	else if (dataFlag == CUDA_DATA_FLAG_$_MATRIX_$)
	{
		if (calculateFlag == CUDA_CAU_TYPE_$_ADD_$)
		{
			if
				(
					(dataSet1->dataType.Matrix.rowSize != dataSet2->dataType.Matrix.rowSize)
					||
					(dataSet2->dataType.Matrix.colSize != dataSet2->dataType.Matrix.colSize)
					)
			{
				printf("试图执行矩阵加法，但是两个矩阵的行列并不相同，已驳回.\n");
				exit(0xDCC8);
			}
		}
		else if (calculateFlag == CUDA_CAU_TYPE_$_MULTIPLE_$)
		{
			if (dataSet1->dataType.Matrix.colSize != dataSet2->dataType.Matrix.rowSize)
			{
				printf("试图执行矩阵乘法，但是第一个矩阵的列和第二个矩阵的行并不相同，已驳回.\n");
				exit(0xDCC8);
			}
		}
		else
		{
			printf("调用的计算类型不被支持，已驳回.\n");
			exit(0xDCC0);
		}
	}
	else
	{
		printf("输入的数据类型错误，已驳回.\n");
		exit(0xACC0);
	}
}

static void ExFreeDataSet_$_VECTOR_$(
	IN_OUT PDATA_SET* dataSet
)
{
	if ((*dataSet)->dataFlag != CUDA_DATA_FLAG_$_VECTOR_$)
	{
		printf("数据类型不符，已驳回.\n");
		exit(0xCFF0);
	}
	ExFreeMem((PVOID*)&((*dataSet)->dataType.Vector.vector));
	ExFreeMem((PVOID*)&(*dataSet));
	return;
}

static void ExFreeDataSet_$_MATRIX_$(
	IN_OUT PDATA_SET* dataSet
)
{
	if ((*dataSet)->dataFlag != CUDA_DATA_FLAG_$_MATRIX_$)
	{
		printf("数据类型不符，已驳回.\n");
		exit(0xCFF0);
	}
	fors(
		(*dataSet)->dataType.Matrix.rowSize,
		ExFreeMem((PVOID*)&((*dataSet)->dataType.Matrix.matrix[j]));
	);
	ExFreeMem((PVOID*)&((*dataSet)->dataType.Matrix.matrix));
	ExFreeMem((PVOID*)&(*dataSet));
	return;
}

void ExFreeDataSet(
	IN_OUT PDATA_SET* dataSet
)
{
	switch ((*dataSet)->dataFlag)
	{
	case CUDA_DATA_FLAG_$_VECTOR_$:
		ExFreeDataSet_$_VECTOR_$(dataSet);
		break;
	case CUDA_DATA_FLAG_$_MATRIX_$:
		ExFreeDataSet_$_MATRIX_$(dataSet);
		break;
	default:
		printf("非法数据类型，已驳回.\n");
		break;
	}
	return;
}

__global__ void myCudaVectorAdd()
{

	return;
}

__global__ void myCudaVectorMultiple()
{

	return;
}

__global__ void myCudaMatrixAdd()
{

	return;
}

__global__ void myCudaMatrixMultiple(
	float* data1,
	float* data2,
	size_t row1,
	size_t col1,
	size_t row2,
	size_t col2,
	float* ret
)
{
	UINT currRow = blockIdx.x * blockDim.x + threadIdx.x;
	UINT currCol = blockIdx.y * blockDim.y + threadIdx.y;
	float sum = 0.0;
	for (size_t j = 0; j < col1; j++)
	{
		sum += data1[currRow * col1 + j] * data2[j * col2 + currCol] + currRow * 10.0;//weightAngle;
	}
	ret[currRow * col2 + currCol] = sum;
	return;
}

void cudaExFreeMem(
	IN_OUT PVOID* _GPU_mem
)
{
	cudaFree(*_GPU_mem);
	*_GPU_mem = NULL;
	return;
}

void callCuda(
	IN PDATA_SET dataSet1,
	IN PDATA_SET dataSet2,
	IN myCudaDataFlag dataFlag,
	IN myCudaCalculateFlag calculateFlag,
	OUT_HOST_PTR float** ret
)
{
	safetyCheck(dataSet1, dataSet2, dataFlag, calculateFlag);

	float* _host_linerData1 = NULL;
	float* _host_linerData2 = NULL;

	makeCudaFriendlyData(dataSet1, &_host_linerData1);
	makeCudaFriendlyData(dataSet2, &_host_linerData2);

	float* _device_linerData1 = NULL;
	float* _device_linerData2 = NULL;

	float* _device_result = NULL;
	size_t _public_resultSize = 0x0;

	if (dataFlag == CUDA_DATA_FLAG_$_VECTOR_$ && calculateFlag == CUDA_CAU_TYPE_$_ADD_$)
	{
		_public_resultSize = dataSet1->dataType.Vector.size;
		cudaMalloc(&_device_result, _public_resultSize * sizeof(float));
	}
	if (dataFlag == CUDA_DATA_FLAG_$_VECTOR_$ && calculateFlag == CUDA_CAU_TYPE_$_MULTIPLE_$)
	{
		_public_resultSize = 1;
		cudaMalloc(&_device_result, _public_resultSize * sizeof(float));
	}
	if (dataFlag == CUDA_DATA_FLAG_$_MATRIX_$ && calculateFlag == CUDA_CAU_TYPE_$_ADD_$)
	{
		_public_resultSize = dataSet1->dataType.Matrix.rowSize * dataSet1->dataType.Matrix.colSize;
		cudaMalloc(&_device_result, _public_resultSize * sizeof(float));
	}
	if (dataFlag == CUDA_DATA_FLAG_$_MATRIX_$ && calculateFlag == CUDA_CAU_TYPE_$_MULTIPLE_$)
	{
		_public_resultSize = dataSet1->dataType.Matrix.rowSize * dataSet2->dataType.Matrix.colSize;
		printf("kernel: _public_resultSize: %zu Bytes CUDA Memory Allocated.\n", _public_resultSize);
		cudaMalloc(&_device_result, _public_resultSize * sizeof(float));

		cudaMalloc(&_device_linerData1, dataSet1->dataType.Matrix.rowSize * dataSet1->dataType.Matrix.colSize * sizeof(float));
		cudaMalloc(&_device_linerData2, dataSet2->dataType.Matrix.rowSize * dataSet2->dataType.Matrix.colSize * sizeof(float));

		cudaMemcpy(_device_linerData1, _host_linerData1, dataSet1->dataType.Matrix.rowSize * dataSet1->dataType.Matrix.colSize * sizeof(float), cudaMemcpyHostToDevice);
		cudaMemcpy(_device_linerData2, _host_linerData2, dataSet2->dataType.Matrix.rowSize * dataSet2->dataType.Matrix.colSize * sizeof(float), cudaMemcpyHostToDevice);

		dim3 threadEx = { 0 };
		threadEx.x = 32;
		threadEx.y = 32;
		threadEx.z = 1;

		dim3 blockEx = { 0 };
		blockEx.x = 100;
		blockEx.y = 2;
		blockEx.z = 1;

		size_t data1_row = dataSet1->dataType.Matrix.rowSize;
		size_t data1_col = dataSet1->dataType.Matrix.colSize;
		size_t data2_row = dataSet2->dataType.Matrix.rowSize;
		size_t data2_col = dataSet2->dataType.Matrix.colSize;

		cudaEvent_t start, stop;
		float elapsedTime;
		cudaEventCreate(&start);
		cudaEventCreate(&stop);
		cudaEventRecord(start, 0);

		myCudaMatrixMultiple << <blockEx, threadEx >> > (_device_linerData1, _device_linerData2, data1_row, data1_col, data2_row, data2_col, _device_result);

		cudaEventRecord(stop, 0);
		cudaEventSynchronize(stop);
		cudaEventElapsedTime(&elapsedTime, start, stop);

		printf("CUDA time: %f ms\n", elapsedTime);
	}
	//定义主机CUDA格式向量，作为《返回值》，大小和前文的resultSize相同：
	float* _host_result = NULL;
	_host_result = (float*)malloc(_public_resultSize * sizeof(float));
	if (_host_result != NULL)
	{
		cudaMemcpy(_host_result, _device_result, _public_resultSize * sizeof(float), cudaMemcpyDeviceToHost);
		*ret = _host_result;

		cudaExFreeMem((PVOID*)&_device_result);
		cudaExFreeMem((PVOID*)&_device_linerData2);
		cudaExFreeMem((PVOID*)&_device_linerData1);
		ExFreeMem((PVOID*)&_host_linerData2);
		ExFreeMem((PVOID*)&_host_linerData1);
	}
	else
	{
		ExFreeMem((PVOID*)&_host_result);

		cudaExFreeMem((PVOID*)&_device_result);
		cudaExFreeMem((PVOID*)&_device_linerData2);
		cudaExFreeMem((PVOID*)&_device_linerData1);
		ExFreeMem((PVOID*)&_host_linerData2);
		ExFreeMem((PVOID*)&_host_linerData1);
		printf("设备GPU内存运算结果指针为空，已驳回.\n");
		*ret = NULL;
		exit(0xFFFF);
	}
	cudaDeviceReset();
	return;
}

void ExFreeRgbTensor(
	IN_CLEAR_OUT PRGB_TENSOR* tensor
)
{
	if (*tensor == NULL)
	{
		printf("已经为空.\n");
	}
	forss(
		(*tensor)->depth, (*tensor)->height,
		ExFreeMem((PVOID*)&(*tensor)->RGBtensor[j][i]);,
	);
	fors(
		(*tensor)->depth,
		ExFreeMem((PVOID*)&(*tensor)->RGBtensor[j]);
	);
	ExFreeMem((PVOID*)&(*tensor)->RGBtensor);
	ExFreeMem((PVOID*)&(*tensor));
	return;
}

void playRgbTensor(
	IN_OUT PRGB_TENSOR* rgbTensor
)
{
	//当前，rgbTensor是一个由主机分配的未释放内存.
	SIZE_T dimensions[MAX_DIMENSION_SIZE] = { (*rgbTensor)->height, (*rgbTensor)->width, 0 };

	return;
}

void transRgbTensor2ImgOnDisk(
	IN_CLEAR_OUT PRGB_TENSOR* rgbTensor,
	IN CONST WCHAR* imgName
)
{
	PVOID img = malloc((*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1) + 0x36 + 0x36);
	*(USHORT*)((ULONG64)img) = 0x4D42;
	*(ULONG*)((ULONG64)img + 2) = (ULONG)((*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1) + 0x36);
	*(ULONG*)((ULONG64)img + 6) = 0xCDCDCDCD;
	*(ULONG*)((ULONG64)img + 10) = 0x00000036;
	*(ULONG*)((ULONG64)img + 14) = 0x00000028;
	*(ULONG*)((ULONG64)img + 18) = (ULONG)((*rgbTensor)->width);
	*(ULONG*)((ULONG64)img + 22) = (ULONG)((*rgbTensor)->height);
	*(USHORT*)((ULONG64)img + 26) = 0x0001;
	*(USHORT*)((ULONG64)img + 28) = 0x0020;
	*(ULONG*)((ULONG64)img + 30) = 0x00000000;
	*(ULONG*)((ULONG64)img + 34) = (ULONG)((*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1));
	RtlZeroMemory((PVOID)((ULONG64)img + 38), 16);
	size_t k = (*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1) - 4;
	for (size_t j = 0; j < ((*rgbTensor)->height); j++)
	{
		for (size_t i = 0; i < ((*rgbTensor)->width); i++)
		{
			*(UCHAR*)((ULONG64)img + 54 + k + 0) = (*rgbTensor)->RGBtensor[2][j][((*rgbTensor)->width) - i - 1];
			*(UCHAR*)((ULONG64)img + 54 + k + 1) = (*rgbTensor)->RGBtensor[1][j][((*rgbTensor)->width) - i - 1];
			*(UCHAR*)((ULONG64)img + 54 + k + 2) = (*rgbTensor)->RGBtensor[0][j][((*rgbTensor)->width) - i - 1];
			*(UCHAR*)((ULONG64)img + 54 + k + 3) = 0xFF;
			k -= 4;
		}
	}
	*(ULONG*)((ULONG64)img + 54 + (ULONG64)((*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1))) = 0xFDFDFDFD;
	RtlZeroMemory((PVOID)((ULONG64)img + 54 + (ULONG64)((*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1)) + 4), 0x32);
	HANDLE file = NULL;
	CONST WCHAR* path = (CONST WCHAR*)imgName;
	file = CreateFileW(
		path,
		GENERIC_WRITE,
		0,
		NULL,
		CREATE_ALWAYS,
		FILE_ATTRIBUTE_NORMAL,
		NULL
	);
	WriteFile(file, img, (*rgbTensor)->width * (*rgbTensor)->height * ((*rgbTensor)->depth + 1) + 0x36 + 0x36, NULL, NULL);
	CloseHandle(file);
	ExFreeRgbTensor(rgbTensor);
	ExFreeMem((PVOID*)&img);
	return;
}