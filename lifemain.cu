#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <windows.h>
#include <time.h>

#define IN
#define OUT
#define OUT_PTR
#define SHOW_LOG

#define ASSERT(p) (p) ? 1:exit(0xFFF);

#pragma warning(disable:6387)
#pragma warning(disable:6385)
#pragma warning(disable:6011)
#pragma warning(disable:28183)

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
    IN HDC nakedScreenImage,
    IN HBITMAP memImg,
    IN BOOLEAN isSaveToDisk
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
        nakedScreenImage,
        memImg,
        img,
        (BITMAPINFO*)imgInfoHeaderPointer
    );

    initializeFileHeader(
        imgFileHeaderPointer,
        (DWORD)sizeof(BITMAPFILEHEADER) + (DWORD)sizeof(BITMAPINFOHEADER),
        imgPixelSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER),
        0x4D42
    );

    if (isSaveToDisk)
    {
        HANDLE hFile = NULL;
        saveImg2Disk(
            &hFile,
            L"E:\\desk",
            L"newScreenSnapShot",
            imgFileHeaderPointer,
            imgInfoHeaderPointer,
            imgPixelHeader,
            imgPixelSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER)
        );
        CloseHandle(hFile);
    }

    ret->filePointer = imgFileHeaderPointer;
    ret->infoPointer = imgInfoHeaderPointer;
    ret->pixelPointer = imgPixelHeader;

    return ret;
}

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

int main()
{
    Point leftTop = { 0, 0 };
    Point rightBottom = { 1920, 1080 };

    HDC screenDC = GetDC(NULL);
    BITMAP img0 = { 0 };
    HDC* memDC = NULL;
    HBITMAP* memImg = NULL;
    transScreenDC2Img(screenDC, &img0, leftTop, rightBottom, &memDC, &memImg);
    PIMG img = makeImg(img0, screenDC, *memImg, 1);
    ExFreeMem((PVOID*)&img->filePointer);
    ExFreeMem((PVOID*)&img->infoPointer);
    ExFreeMem((PVOID*)&img->pixelPointer);
    DeleteObject(*memImg);
    DeleteObject(*memDC);
    ExFreeMem((PVOID*)&memImg);
    ExFreeMem((PVOID*)&memDC);
    ReleaseDC(NULL, screenDC);
    ExFreeMem((PVOID*)&img);

    return 0;
}
