% =========================================================================
% 실습: 무작위 SNR과 Target BER로 적응형 변조 데이터셋 생성하기
% =========================================================================
% 학습 목표
% (1) rand()로 N개의 SNR과 목표 BER을 각각 무작위 생성한다.
% (2) BPSK/QPSK/16-QAM의 이론 BER을 벡터 연산으로 계산한다.
% (3) 목표 BER을 만족하는 방식 중 가장 높은 차수의 변조를 정답으로 붙인다.
% (4) 입력 2개, 정답 1개로 이루어진 CSV 파일을 저장한다.
%
% CSV 컬럼은 정확히 아래 3개만 포함한다.
%   SNR_dB      : 심볼 에너지 기준 Es/N0 [dB], 실수
%   TargetBER   : 허용 가능한 최대 BER, 실수
%   Modulation  : NA, BPSK, QPSK, QAM16 중 하나, 문자열
%
% GNU Octave 호환 코드
% AWGN, 평균 심볼 에너지 Es=1, Gray-coded QPSK/16-QAM 가정
% =========================================================================

clear;
clc;
close all;

rng(42);

%% 1. 데이터 개수 및 생성 범위 설정
N = 30000;             % 생성할 샘플 수
SNR_min_dB = 0;        % SNR 하한 [dB]
SNR_max_dB = 20;       % SNR 상한 [dB]
BER_min = 1e-4;        % 목표 BER 하한
BER_max = 1e-1;        % 목표 BER 상한

%% 2. DNN 입력 데이터 2개 생성
% [입력 1] SNR_dB 생성: 0~20 dB 사이의 균등분포 난수
SNR_dB = SNR_min_dB + ...
    (SNR_max_dB - SNR_min_dB) * rand(N,1);

% [입력 2] TargetBER 생성: 로그 영역에서 균등분포 난수
logBER = log10(BER_min) + ...
    (log10(BER_max) - log10(BER_min)) * rand(N,1);
TargetBER = 10.^logBER;

%% 3. 각 입력 SNR에 해당하는 이론 BER 계산
% SNR: dB를 선형값으로 변환 (Es/N0 = 10^(SNR_dB/10))
SNR = 10.^(SNR_dB/10);

% Q 함수 정의
Qfun = @(x) 0.5 * erfc(x/sqrt(2));

% BPSK 이론 BER
BER_BPSK = Qfun(sqrt(2*SNR));

% QPSK 이론 BER (Gray 매핑)
BER_QPSK = Qfun(sqrt(SNR));

% 16-QAM 이론 BER
a = sqrt(SNR/5);
BER_QAM16 = 0.75 * Qfun(a) ...
          + 0.5  * Qfun(3*a) ...
          - 0.25 * Qfun(5*a);

%% 4. 정답 라벨 생성
% 목표 BER을 만족하는 가장 높은 차수의 변조 방식 선택
% GNU Octave에서는 문자열을 cell array로 저장한다.
Modulation = repmat({"NA"}, N, 1);

% (1) BPSK 조건을 만족하면 BPSK 지정
idx_BPSK = (BER_BPSK <= TargetBER);
Modulation(idx_BPSK) = repmat({"BPSK"}, sum(idx_BPSK), 1);

% (2) QPSK 조건을 만족하면 BPSK를 QPSK로 변경
idx_QPSK = (BER_QPSK <= TargetBER);
Modulation(idx_QPSK) = repmat({"QPSK"}, sum(idx_QPSK), 1);

% (3) 16-QAM 조건을 만족하면 QPSK를 QAM16으로 변경
idx_QAM16 = (BER_QAM16 <= TargetBER);
Modulation(idx_QAM16) = repmat({"QAM16"}, sum(idx_QAM16), 1);

%% 5. CSV 파일 저장
% pwd를 이용하여 현재 작업 폴더의 전체 경로 지정
fileName = fullfile(pwd, 'AdaptiveModulation_Random.csv');
fid = fopen(fileName, 'w');
if fid == -1
    error('CSV 파일을 생성할 수 없습니다.');
end

% CSV 첫 번째 행: 열 이름
fprintf(fid, 'SNR_dB,TargetBER,Modulation\n');

% 데이터 저장
for i = 1:N
    fprintf(fid, '%.10f,%.10e,%s\n', ...
        SNR_dB(i), TargetBER(i), Modulation{i});
end
fclose(fid);

%% 6. 저장 결과 확인
fprintf('\n====================================\n');
fprintf('       데이터셋 생성 완료\n');
fprintf('====================================\n');
fprintf('저장한 파일: %s\n', fileName);
fprintf('데이터 행 수 = %d\n', N);
fprintf('데이터 열 수 = 3\n');

%% 7. CSV 데이터 미리보기
disp(' ');
disp('CSV 데이터 미리보기 (처음 최대 10행)');
disp('------------------------------------');
fprintf('%12s %15s %10s\n', 'SNR_dB', 'TargetBER', 'Modulation');
for i = 1:min(10,N)
    fprintf('%12.6f %15.6e %10s\n', ...
        SNR_dB(i), TargetBER(i), Modulation{i});
end

%% 8. 클래스별 데이터 개수 확인
classes = {"NA", "BPSK", "QPSK", "QAM16"};
disp(' ');
disp('변조 방식별 데이터 개수');
disp('------------------------------------');
for k = 1:numel(classes)
    nClass = sum(strcmp(Modulation, classes{k}));
    percentage = 100 * nClass / N;
    fprintf('%-5s : %6d개 (%.1f%%)\n', ...
        classes{k}, nClass, percentage);
end
fprintf('====================================\n');
fprintf('             실행 종료\n');
fprintf('====================================\n');
