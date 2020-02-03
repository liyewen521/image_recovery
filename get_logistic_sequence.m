function [logistic_sequence_output] = get_logistic_sequence(initial_value,logistic_parameter_a,height,width)
    % 用Logistic映射系统生成混沌序列
    % 3.5699456<logistic_parameter_a<=4
    % 0<= initial_value <= 1
%     initial_value = 0.2;
%     logistic_parameter_a=3.901;            %取logistic映射的参数a
    logistic_original_sequence = 0 : width*height-1;            %生成一维自然数组
    logistic_sequence=ones(1,width*height)*initial_value;  %设定logistic进行len次迭代后得到的序列,设初始值为0.1
    % 利用logistic映射生成伪随机序列。
    for i=2:width*height
        logistic_sequence(i)=logistic_parameter_a*logistic_sequence(i-1)*(1-logistic_sequence(i-1));
    end
    logistic_sequence_combine=[logistic_sequence;logistic_original_sequence];
    for i = 1 : width*height - 1
        flag=0;
        for j = 1 : width*height - i       
            if logistic_sequence_combine(1,j)>logistic_sequence_combine(1,j+1)
                temp=logistic_sequence_combine(:,j);
                logistic_sequence_combine(:,j)=logistic_sequence_combine(:,j+1);
                logistic_sequence_combine(:,j+1)=temp;
                flag=1;
            end
        end
        if(~flag)    %结束条件
            break;
        end
    end
    % load('logistic_sequence_combine.mat');
    logistic_sequence_output = logistic_sequence_combine(2,:);
    
end

