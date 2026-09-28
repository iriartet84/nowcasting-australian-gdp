# Australian GDP Nowcasting with a Dynamic Factor Model

## Overview

This project develops a **Dynamic Factor Model (DFM)** to nowcast Australian real GDP growth using a combination of quarterly GDP data and seven monthly economic and financial indicators.

The model adapts the **Stock–Watson coincident-indicator framework** to the Australian economy, extending the baseline specification to incorporate a richer indicator set, mixed-frequency observations, idiosyncratic dynamics, and a genuinely leading indicator.

The model is estimated recursively using a **Kalman filter** and **maximum likelihood**, with the latent factor interpreted as a common measure of Australian economic activity.

## Research Question

> **Can a latent common factor extracted from high-frequency economic and financial indicators provide a timely estimate of Australian real GDP growth?**

Australia provides an interesting application because its economic cycle is influenced by both domestic activity and external commodity demand, particularly through its role as a major resource exporter.

The indicator set therefore combines measures of:

* Domestic production
* Employment
* Construction
* Household demand
* Commodity exports
* Financial markets
* Leading economic conditions

## Model

The model assumes that each observed indicator contains information about an unobserved common economic factor:

$$
y_{i,t} = \lambda_i f_t + e_{i,t}
$$

where:

* \(y_{i,t}\) is the observed indicator
* \(f_t\) is the latent common factor
* \(\lambda_i\) is the factor loading
* \(e_{i,t}\) is the series-specific component

The common factor follows an AR(2) process:

$$
f_t = \phi_1 f_{t-1} + \phi_2 f_{t-2} + w_t
$$

while the idiosyncratic components are also modelled dynamically:

$$
e_{i,t} = \psi_{i,1}e_{i,t-1}+\psi_{i,2}e_{i,t-2}+\epsilon_{i,t}
$$

The complete system is represented in **state-space form** and estimated using the Kalman filter and maximum likelihood.

### Mixed-frequency structure

The model combines:

* **Quarterly GDP**, the target variable
* **Monthly indicators**, providing more timely information

Missing quarterly GDP observations within the monthly state-space framework are handled naturally by the Kalman filter.

GDP is linked to a weighted window of monthly factor observations, allowing the model to translate the monthly latent factor into quarterly economic growth.

The OECD Composite Leading Indicator is treated differently from the contemporaneous indicators and enters as a leading variable.

## Indicator Selection

The final model contains seven monthly indicators in addition to GDP:

| Indicator                        | Frequency | Transformation | Role                        |
| -------------------------------- | --------- | -------------- | --------------------------- |
| Industrial production            | Monthly   | Δ log          | Domestic activity           |
| Dwelling approvals               | Monthly   | Δ log          | Construction / housing      |
| New motor vehicle sales          | Monthly   | Δ log          | Durable consumption         |
| Employment                       | Monthly   | Δ log          | Labour market               |
| ASX stock index                  | Monthly   | Δ log          | Financial conditions        |
| Commodity exports                | Monthly   | Δ log          | External / commodity sector |
| OECD Composite Leading Indicator | Monthly   | Log level      | Leading indicator           |

The stock index is aggregated from its original daily frequency to monthly frequency.

The sample used for estimation begins in **June 2000**, as the ASX series is the binding constraint on the common sample.

## Indicator Selection & PCA

The initial indicator selection was guided by economic reasoning about the Australian business cycle.

A **Principal Component Analysis (PCA)** was then used as a diagnostic to assess whether the selected variables co-move with a broader common economic cycle.

The PCA also considered additional candidate variables, including commodity prices, exchange rates, business confidence, consumer confidence, unemployment, and global commodity benchmarks.

The results provided evidence that several commodity and financial variables contain substantial common variation. However, variables such as copper prices were excluded because their relationship with the Australian economy is less direct, while coal and iron ore exposure is already represented through Australia's export and commodity channels.

PCA was therefore used as a **validation and diagnostic tool rather than as the final forecasting model**.

## Estimation

The state-space model is estimated using:

* **Kalman filtering**
* **Maximum likelihood estimation**
* Numerical optimization
* Finite-difference Hessian estimation
* Cramér–Rao standard errors

The full specification contains **34 freely estimated parameters**.

Identification of the latent factor's scale is achieved by fixing the variance of the factor innovation:

$$
\sigma_w^2 = 1
$$

rather than fixing one of the factor loadings.

## Results

The estimated common factor captures a substantial share of the observed cyclical variation in Australian GDP growth.

The correlation between observed GDP growth and the **factor-only fitted GDP series** is:

$$
\rho = 0.9617
$$

This indicates strong co-movement between the latent common factor and observed GDP growth within the estimation sample.

The factor also tracks major turning points, including the sharp contraction associated with the **2020 pandemic shock**.

The estimated factor loadings show particularly strong relationships for:

* Employment: **0.8531**
* GDP: **0.5995**
* Vehicle sales: **0.3639**
* Construction: **0.1469**
* Commodity exports: **0.1396**

Industrial production, the ASX stock index, and the Composite Leading Indicator have much smaller estimated loadings in the final specification.

These results suggest that labour-market and domestic-demand indicators provide particularly strong signals of the common cyclical component in this sample.

### GDP nowcasts

Using the estimated latent factor and its state forecast, the model produces estimates for upcoming quarterly GDP growth.

The final model generated:

* **Q2 2026:** 0.41%
* **Q3 2026:** 0.65%

These estimates represent model-implied GDP growth based on the information structure available to the model and should be distinguished from realized GDP outcomes.

## Model Diagnostics

The project uses several diagnostics to assess whether the estimated factor provides economically meaningful information:

* Factor versus standardized GDP growth
* Factor-only fitted GDP versus observed GDP
* Factor-implied GDP forecasts
* Factor loading significance
* PCA correlations
* State-space estimation diagnostics
* Behaviour around major economic turning points

A perfect correlation between the full fitted GDP series and observed GDP at months where GDP is observed is expected because the Kalman filter reconstructs the data used in estimation. The more informative diagnostic is the **0.9617 correlation of the factor-only component**, which isolates the common cyclical signal.

## Data

The project combines data from:

* **Australian Bureau of Statistics (ABS)**
* **OECD**
* **Bloomberg**

The dataset contains economic activity, labour-market, construction, consumption, financial-market, and commodity-export indicators.

## Research Workflow

```text
Monthly & Quarterly Data
          │
          ▼
   Transformations
          │
          ▼
   Indicator Selection
          │
          ▼
          PCA
          │
          ▼
   State-Space Model
          │
          ▼
    Kalman Filter
          │
          ▼
 Maximum Likelihood
          │
          ▼
   Latent Economic Factor
          │
          ▼
      GDP Nowcast
```
