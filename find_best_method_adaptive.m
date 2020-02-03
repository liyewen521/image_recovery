function [watermark_data] = find_best_method_adaptive(image_data,table_height,table_width,block_height,block_width)
% block profile
%     a(1,1) a(2,1)
%     a(3,1) a(4,1)
    image_data = double(image_data);
    for i = 1 : table_height
        for j = 1 : table_width
            a(1,1) = image_data(i*block_height-1,j*block_width-1);
            a(2,1) = image_data(i*block_height-1,j*block_width);
            a(3,1) = image_data(i*block_height,j*block_width-1);
            a(4,1) = image_data(i*block_height,j*block_width);
            block_max = max([floor(a(1,1)/8)*8 floor(a(2,1)/8)*8 floor(a(3,1)/8)*8 floor(a(4,1)/8)*8]);
            block_min = min([floor(a(1,1)/8)*8 floor(a(2,1)/8)*8 floor(a(3,1)/8)*8 floor(a(4,1)/8)*8]);
            k = 0;
            distance = [];
            for pixel_traverse = block_min : 8 : block_max
                k=k+1;
                distance(k,1) = sum([(pixel_traverse-a(1,1))^2 (pixel_traverse-a(2,1))^2 (pixel_traverse-a(3,1))^2 (pixel_traverse-a(4,1))^2]);
                distance(k,2) = pixel_traverse;
            end
            distance = sortrows(distance,1);
            watermark_data(i,j) = distance(1,2);
        end
    end
    watermark_data = uint8(watermark_data);
end

