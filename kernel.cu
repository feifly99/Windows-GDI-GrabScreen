#include "GDI_CUDA_HEADER.cuh"

int main()
{
    Point leftTop = { 0, 0 };
    Point rightBottom = { 200, 200 };
    HDC screenDC = GetDC(NULL);
    BITMAP img0 = { 0 };
    HDC* memDC = NULL;
    HBITMAP* memImg = NULL;
    transScreenDC2Img(screenDC, &img0, leftTop, rightBottom, &memDC, &memImg);
    PIMG img = makeImg(img0, &screenDC, &memDC, &memImg, YES, L"EXEx");
    PRGB_TENSOR rgbTensor = NULL;
    makeImgRgbTensor(&img, &rgbTensor);
    //从现在开始，仅有rgbTensor是可用内存！
    playRgbTensor(&rgbTensor);

    transRgbTensor2ImgOnDisk(&rgbTensor, L"E:\\desk\\woaini.png");
    return 0;
}