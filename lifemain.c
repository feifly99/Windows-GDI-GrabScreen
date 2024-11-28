#include <stdio.h>
#include <windows.h>
#include <time.h>

#define IN
#define OUT
#define SHOW_LOG

#define ASSERT(p) (p) ? 1:exit(0xFFF);

#define getNakedOriginalScreen GetDC
#define makeImageCodeSpace CreateCompatibleDC
#define makeImageInstanceSpace CreateCompatibleBitmap 
#define linkImageCodeAndInstance SelectObject
#define transNakedScreenToImageCode BitBlt

void echo(
    IN SHOW_LOG WCHAR* str
)
{
    MessageBoxW(NULL, str, NULL, MB_OK);
}

void initializeBitMapInfoHeader(
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

void createImageFile(
    IN WCHAR* w_filePath,
    OUT HANDLE* hFile
)
{
    *hFile = CreateFile(
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
    BITMAP bmpScreen,
    BITMAPINFOHEADER bi
)
{
    return ((bmpScreen.bmWidth * bi.biBitCount + 31) / 32) * 4 * bmpScreen.bmHeight;
}

int CaptureImage(
    IN HANDLE windowHandle,
    IN int leftX,
    IN int leftY,
    IN int rightX,
    IN int rightY,
    WCHAR* dirPath, 
    WCHAR* filename
)
{
    int width = rightX - leftX;
    int height = rightY - leftY;
    HDC nakedScreenImage = getNakedOriginalScreen(windowHandle); //这里是NULL
    HDC hiddenImageCode = makeImageCodeSpace(nakedScreenImage);
    HBITMAP hiddenImageInstance = makeImageInstanceSpace(nakedScreenImage, width, height);
    linkImageCodeAndInstance(hiddenImageCode, hiddenImageInstance);
    transNakedScreenToImageCode(
        hiddenImageCode,
        0, 0,
        width, height,
        nakedScreenImage,
        leftX, leftY,
        SRCCOPY
    );
    BITMAP realImage = { 0 };
    GetObjectW(hiddenImageInstance, sizeof(BITMAP), &realImage);
    BITMAPINFOHEADER realImageInfoHeader = { 0 };
    initializeBitMapInfoHeader(realImage, &realImageInfoHeader);
    DWORD dwBmpSize = getBmpSize(realImage, realImageInfoHeader);
    HANDLE hDIB = GlobalAlloc(GHND, dwBmpSize);
    ASSERT(hDIB != NULL);
    PVOID realImagePointer = (PVOID)GlobalLock(hDIB);
    GetDIBits(
        nakedScreenImage,
        hiddenImageInstance,
        0,
        (UINT)realImage.bmHeight,
        realImagePointer,
        (BITMAPINFO*)&realImageInfoHeader,
        DIB_RGB_COLORS
    );
    GlobalUnlock(hDIB);
    GlobalFree(hDIB);
    DeleteObject(hiddenImageInstance);
    DeleteObject(hiddenImageCode);
    ReleaseDC(NULL, nakedScreenImage);
    return 0;
}

int main()
{
    int s = 0;
    int dis_l_x = 2;
    int dis_l_y = 422;
    int dis_r_x = 74;
    int dis_r_y = 508;
    float factor = 0.8f;
    clock_t start = clock();
    for (s = 0; s < 100; s++)
    {
        CaptureImage(
            NULL, 
            (int)((float)dis_l_x / factor),
            (int)((float)dis_l_y / factor),
            (int)((float)dis_r_x / factor),
            (int)((float)dis_r_y / factor),
            L".\\", 
            L"screen"
        );//保存当前目录
    }
    clock_t end = clock();
    double time_taken = (double)(end - start) / CLOCKS_PER_SEC;
    printf("Average time per screenshot: %.4lf seconds\n", time_taken / (double)s);

    return 0;
}
/*
    WCHAR FilePath[MAX_PATH];
    wsprintfW(FilePath, L"%s\\%s.png", dirPath, filename);
    HANDLE hFile = NULL;
    createImageFile(FilePath, &hFile);
    DWORD dwSizeofDIB = dwBmpSize + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
    BITMAPFILEHEADER bmfHeader = { 0 };

    bmfHeader.bfOffBits = (DWORD)sizeof(BITMAPFILEHEADER) + (DWORD)sizeof(BITMAPINFOHEADER);
    bmfHeader.bfSize = dwSizeofDIB; 
    bmfHeader.bfType = 0x4D42; //BM 

    WriteFile(hFile, (LPSTR)&bmfHeader, sizeof(BITMAPFILEHEADER), NULL, NULL);
    WriteFile(hFile, (LPSTR)&realImageInfoHeader, sizeof(BITMAPINFOHEADER), NULL, NULL);
    WriteFile(hFile, (LPSTR)realImagePointer, dwBmpSize, NULL, NULL);
*/