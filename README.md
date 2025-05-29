# 🧾 AMM(Automated Market Maker) 기반의 DEX(Decentralized Exchange)의 설계 및 활용
<br>

**프로젝트 개요** : AMM은 수학적 알고리즘을 기반으로 자산 가격을 자동 조정하며, 블록체인 상의 스마트 컨트랙트를 통해 탈중앙화된 거래를 가능하게 하는 구조이다. 본 프로젝트는 이러한 AMM의 핵심 개념을 바탕으로, 기존 AMM의 단점을 보완한 Uniswap V3 기반 Concentrated Liquidity 모델을 구현하였다. 또한, 스마트 컨트랙트에서 발생하는 가스 비용을 절감하기 위해 Tick 단위 유동성 관리, Liquidity Net(imos 법), Bitmap 구조 등을 활용한 최적화를 수행하였다. 이러한 구조적 개선을 통해, AMM을 결제 시스템에 결합함으로써 실시간 최저가 결제와 자동 환전이 가능한 디지털 자산 기반 결제 인프라로의 확장 가능성을 제시한다.  

<br>
<br>


**프로젝트에 대한 진행 과정 및 자세한 내용은 아래의 노션에서 확인하실 수 있습니다.**
> 📘 프로젝트 상세 내용: [Notion 문서 바로가기](https://swamp-emu-0a7.notion.site/25-1-1adfd415458b80b4a574ebf4b2c52175)

<br>

## 🧩 개발 환경

### 💻 Smart Contract Language
- Solidity ≥ 0.8.28

### ⚙️ JavaScript Runtime
- Node.js ≥ v22.14.0

### 📦 Package Manager
- npm ≥ 11.2.0

### 🛠 Dependencies
- Hardhat ≥ 11.2.0  
- OpenZeppelin ≥ 5.2.0  
- Chai ≥ 4.5.0  

---

## 📄 명령어 사용법

1.  **컴파일**:
  ```bash
    npx hardhat compile
  ```

2. **로컬 환경에 배포**

메인/테스트넷에 배포를 하려면 ETH/테스트 ETH가 필요하므로 지갑이 없다면 Hardhat에서 제공하는 로컬 블록체인 네트워크에 스마트 컨트랙트를 배포하고 테스트 할 수 있다.

2-1. **로컬에 블록체인 네트워크 구축**
```bash
  npx hardhat node
```
2-2. **다른 터미널에서 실행하여 모듈 배포**
```bash
  npx hardhat ignition deploy ./ignition/modules/[원하는 모듈 파일 이름].js --network localhost
```

2-3. **또는, 모든 모듈을 한번에 배포하는 스크립트 실행**
```bash
  node scripts/LocalDeployAll.js
```

3. **테스트 코드 실행**
```bash
  npx hardhat test
```
