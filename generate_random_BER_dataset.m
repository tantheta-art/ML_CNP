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
% 주의: 이 데이터는 무작위 채널 시뮬레이션 결과가 아니라, 무작위로 뽑은
%       입력과 '이론 BER'으로 계산한 정답 레이블의 조합이다.
%       AWGN, 평균 심볼 에너지 Es=1, Gray-coded QPSK/16-QAM을 가정한다.
% =========================================================================

clear;      % 작업 공간(Workspace)에 저장된 변수 삭제
clc;        % 명령 창(Command Window)의 출력 내용 삭제
close all;  % 열려 있는 그림 창 모두 닫기(이 실습에서는 그림을 그리지 않아도 무방)
rng(42);    % 난수 발생기 초기값을 42로 고정: 실행할 때마다 같은 데이터 생성

%% 1. 데이터 개수 및 생성 범위 설정
N = 30000;             % 생성할 샘플 수 = CSV의 데이터 행 개수
SNR_min_dB = 0;        % SNR 하한 [dB]
SNR_max_dB = 20;       % SNR 상한 [dB]
BER_min = 1e-4;        % 목표 BER 하한: 0.0001
BER_max = 1e-1;        % 목표 BER 상한: 0.1

% N=30000이므로 rand(N,1), SNR_dB, TargetBER, Modulation은 모두 30000x1.


%% 2. DNN 입력 데이터 2개 생성
% [입력 1] SNR_dB: [SNR_min_dB, SNR_max_dB]의 균등분포 난수
% rand(N,1)은 0 이상 1 미만의 실수를 N행 1열로 반환한다.
% 여기에 구간 폭을 곱하고 최솟값을 더하면 지정된 범위로 변환된다.
SNR_dB = SNR_min_dB + (SNR_max_dB - SNR_min_dB)*rand(N,1);

% [입력 2] TargetBER: BER 값을 그대로 균등하게 뽑지 않고 로그 영역에서 뽑는다.
% 1e-4~1e-3, 1e-3~1e-2, 1e-2~1e-1 범위가 비슷한 비중으로 나타나도록 한다.
% log10(BER_min)=-4, log10(BER_max)=-1이므로 logBER는 [-4,-1)에서 균등.
logBER = log10(BER_min) + (log10(BER_max) - log10(BER_min))*rand(N,1);

% 10.^logBER: 원소별로 10의 거듭제곱을 계산하는 MATLAB 연산
% .^는 벡터의 각 원소에 각각 거듭제곱을 적용한다는 의미.
TargetBER = 10.^logBER;

%% 3. 각 입력 SNR에 해당하는 이론 BER 계산
% 아래 계산에 사용하는 SNR은 Es/N0(심볼 에너지 기준)이다.
% dB --> 선형 변환: gamma_s = 10^(SNR_dB/10)
% SNR_dB가 N x 1이므로 SNR 역시 N x 1이다.
SNR = 10.^(SNR_dB/10);

% 익명 함수(anonymous function): Qfun(x) = 0.5*erfc(x/sqrt(2))
% @(x)는 '입력 인수가 x인 함수'를 정의한다는 뜻이다.
% erfc는 MATLAB의 여오차함수(complementary error function)이다.
Qfun = @(x) 0.5*erfc(x/sqrt(2));

% 세 BER 결과도 각각 N x 1 열벡터이다.
BER_BPSK = Qfun(sqrt(2*SNR));      % BPSK 이론 BER
BER_QPSK = Qfun(sqrt(SNR));        % QPSK 이론 BER (Gray 매핑)
a = sqrt(SNR/5);
BER_QAM16 = 0.75*Qfun(a) + 0.5*Qfun(3*a) - 0.25*Qfun(5*a); % 16-QAM 이론 BER

%% 4. 정답 라벨 생성: 목표 BER을 만족하는 최고 차수 변조 방식
% repmat("NA",N,1) : 문자열 "NA"를 N행 1열로 반복한 string 배열 생성
% NA의 의미는 목표 BER을 만족하는 변조 방식이 하나도 없다는 것이다.
Modulation = repmat("NA", N, 1);

% (A <= B)는 각 행마다 참/거짓을 구하는 논리 연산이다.
% BER_BPSK <= TargetBER는 N x 1 logical 배열로 반환된다.
% Modulation(조건) = "BPSK"는 '조건이 참인 행'만 변경한다.
Modulation(BER_BPSK <= TargetBER) = "BPSK";
Modulation(BER_QPSK <= TargetBER) = "QPSK";
Modulation(BER_QAM16 <= TargetBER) = "QAM16";

% QPSK의 BER도 목표값을 만족하면 기존 라벨(BPSK 포함)을 QPSK로 덮어쓴다.
% QAM16까지 허용되면 최종 라벨이 QAM16으로 바뀐다.
% 최종 라벨은 '조건을 만족하는 가장 높은 차수'가 된다.


%% 5. CSV 파일에 저장할 3개 열만 table로 묶기
% table은 숫자 벡터와 문자열 벡터를 열별로 함께 관리할 수 있는 자료형.
% 'VariableNames'는 출력 CSV 파일 첫 번째 줄에 기록할 열 이름이다.

Dataset = table(SNR_dB, TargetBER, Modulation, ...
    'VariableNames', {'SNR_dB','TargetBER','Modulation'});

% writetable은 table을 쉼표로 구분된 텍스트 파일(CSV)로 저장한다.
% 파일명만 지정하면 MATLAB '현재 작업 폴더'에 저장된다.
fileName = 'AdaptiveModulation_Random.csv';
writetable(Dataset, fileName);

%% 6. 저장 확인
% pwd : MATLAB 현재 작업 폴더의 전체 경로
% fullfile : 운영체제에 맞는 경로 구분자로 폴더와 파일명을 이어 줌
fprintf('저장한 파일: %s\n', fullfile(pwd, fileName));

% height: table의 행 개수, width: table의 열 개수
fprintf('데이터 행 수 = %d, 열 수 = %d\n', height(Dataset), width(Dataset));

% min(10,N): N이 10보다 작더라도 인덱스 초과가 발생하지 않게 한다.
disp('CSV 데이터 미리보기 (처음 최대 10행):');
disp(Dataset(1:min(10,N), :));

% sum(논리 배열): 참(true=1)의 개수를 센다.
% 각 정답 클래스의 샘플 수를 확인하여 데이터 불균형을 살핀다.
classes = ["NA", "BPSK", "QPSK", "QAM16"];
for k = 1:numel(classes)    % numel: 배열에 들어 있는 원소 개수
    nClass = sum(Modulation == classes(k));
    fprintf('%-5s : %6d개 (%.1f%%)\n', ...
        classes(k), nClass, 100*nClass/N);
end

