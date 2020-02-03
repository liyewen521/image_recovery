function [Watermarked_Pixel] = smooth_function(Original_Pixel,LSB3,LSB2,LSB1)   
%计算原像素的LSB1，LSB2，LSB3和待插入的LSB1，LSB2，LSB3的差值
    y = double(1*LSB1+2*LSB2+4*LSB3) - double(bitget(Original_Pixel,1)*1+bitget(Original_Pixel,2)*2+bitget(Original_Pixel,3)*4);
%根据平滑函数来对LSB1，2，3进行嵌入
    if abs(y) < 5
        Watermarked_Pixel =  uint8(double(Original_Pixel) + y);
    elseif y <= -5
        Watermarked_Pixel =  uint8(double(Original_Pixel) + y + 8);
    elseif y >= 5
        if (Original_Pixel==0) && (y==5||y==6||y==7)
            Watermarked_Pixel =  4*LSB3+2*LSB2+1*LSB1;  
        elseif (Original_Pixel==1) && (y==5||y==6)
            Watermarked_Pixel =  4*LSB3+2*LSB2+1*LSB1;
        elseif (Original_Pixel==2) && (y==5)
            Watermarked_Pixel =  4*LSB3+2*LSB2+1*LSB1;
        else
            Watermarked_Pixel =  uint8(double(Original_Pixel) + y - 8);
        end
        
    end        
end

