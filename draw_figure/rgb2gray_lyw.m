clc;        % 清除命令行窗口
clear;      % 清除变量
close all;  % 清除绘图

MyYuanLaiPic = imread('School_Motto.bmp');%读取RGB格式的图像 
%显示原来的RGB图像  
figure(1);  
imshow(MyYuanLaiPic);  
 
MyFirstGrayPic = rgb2gray(MyYuanLaiPic);%用已有的函数进行RGB到灰度图像的转换   
%显示经过系统函数运算过的灰度图像  
figure(2);  
imshow(MyFirstGrayPic);

 
 
[rows , cols , colors] = size(MyYuanLaiPic);%得到原来图像的矩阵的参数  
MidGrayPic1 = zeros(rows , cols);%用得到的参数创建一个全零的矩阵，这个矩阵用来存储用下面的方法产生的灰度图像  
MidGrayPic1 = uint8(MidGrayPic1);%将创建的全零矩阵转化为uint8格式，因为用上面的语句创建之后图像是double型的  
 
for i = 1:rows  
    for j = 1:cols  
        sum = 0;  
        for k = 1:colors  
            sum = sum + MyYuanLaiPic(i , j , k) / 3;%进行转化的关键公式，sum每次都因为后面的数字而不能超过255  
        end  
        MidGrayPic1(i , j) = sum;  
    end  
end  
%平均值法转化之后的灰度图像  
figure(3); 
imshow(MidGrayPic1);
 
MidGrayPic2 = zeros(rows , cols);%用得到的参数创建一个全零的矩阵，这个矩阵用来存储用下面的方法产生的灰度图像  
MidGrayPic2 = uint8(MidGrayPic2);%将创建的全零矩阵转化为uint8格式，因为用上面的语句创建之后图像是double型的  
for i = 1:rows  
    for j = 1:cols  
        MidGrayPic2(i , j) =max(MyYuanLaiPic(i,j,:));  
    end  
end  
%最大值法转化之后的灰度图像  
figure(4); 
imshow(MidGrayPic2);
 
 
 
MidGrayPic3 = zeros(rows , cols);%用得到的参数创建一个全零的矩阵，这个矩阵用来存储用下面的方法产生的灰度图像  
MidGrayPic3 = uint8(MidGrayPic3);%将创建的全零矩阵转化为uint8格式，因为用上面的语句创建之后图像是double型的  
 
for i = 1:rows  
    for j = 1:cols  
        MidGrayPic3(i , j) = MyYuanLaiPic(i , j , 1)*0.30+MyYuanLaiPic(i , j , 2)*0.59+MyYuanLaiPic(i , j , 3)*0.11;  
    end  
end  
%加权平均值法转化之后的灰度图像  
figure(5); 
imshow(MidGrayPic3);