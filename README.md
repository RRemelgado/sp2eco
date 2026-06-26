<p align="center">
  <img src="man/figures/project_banner-whiteBackground.png" alt="Project Banner" width="100%">
</p>

## 1. A general framework for generating reference data for ecosystem mapping
<p align="justify">
  Losses of ecosystem extents threaten biodiversity and people. Ecosystem monitoring and conservation in accordance with the Kunming-Montreal Global Biodiversity Framework (GBF) require accurate, regularly updated maps of ecosystem extent. Yet, quality-vetted reference data on ecosystem occurrences required for training and validation of maps remain scarce, non-standardized, and largely inaccessible. In contrast, billions of species-occurrence records are being shared through the Global Biodiversity Information Facility (GBIF). Here, in response to the <a href="https://www.gbif.org/news/3DyM3tK5wgYipqyaHwG2c2/2026-ebbe-nielsen-challenge-open-for-submissions">Ebbe Nielsen challenge of 2026</a>, we present a framework that mobilizes GBIF for generating ‘mapping-grade’ reference data, i.e., data that are of sufficient quality for supporting ecological mapping applications.
</p>

### 1.1. How do the concepts of *species*, *habitat*, and *ecosystem* relate? :jigsaw:
<p align="justify">
  Species are associated with habitats, while ecosystems describe the broader biotic and abiotic systems in which these habitats occur. Because many species occupy only a limited range of habitats, species observations can provide indirect evidence for the occurrence of particular ecosystem types. By combining species-occurrence records with standardized information on species' habitat associations, GBIF data can therefore be mobilized for ecosystem mapping applications. We building on this concept, providing  
</p>

### 1.2. Translating *species* into *ecosystems* requires careful data quality controls :warning:
<p align="justify">
  Simply assigning ecosystems based on habitat associations is insufficient for mapping applications. Ecosystem mapping requires reference data that are aligned with the target mapping resolution and classification scheme, accurately labeled, and with explicit uncertainty characterization, consistent with current good practices in map validation <a href="https://lpvs.gsfc.nasa.gov/documents.html">(Tyukavina et al., 2025)<a/>. Opportunistic species observations are affected by multiple sources of uncertainty, including positional uncertainties, spatial misalignments with mapping units, labeling uncertainty, disagreements among experts regarding species-habitat associations, and species vagrancy beyond documented habitat preferences.
</p>

</br>

  <p align="center">
    <img src="man/figures/figure_1_data_issues.png" style="width: 50%; height: auto; display: block;" />
  </p>
<p align="justify">
  <sub><b>Figure 1. Data issues in translating species occurrences into ecosystems</b>. <b>a)</b> Species occurrences relative to the target mapping grid. The geolocation uncertainty (in grey) creates doubts regarding the class represented by the corresponding species occurrence (in red). <b>b)</b> Occurrence records for a temperate-forest specialist in the Southern Rocky Mountains with observations outside forest areas. <b>c)</b> Occurrences of species specialized in sub-/tropical lowland moist forests overlap with the corresponding biome (in grey, observations in blue), with some extending to savanna regions and temperate rainforests (in red).</sub>
</p>

</br>

### 1.3. How does our framework addresses these issues? :hammer_and_wrench:


In the following section, we guide you through the use of our framework to resolve these issues, supported by practical examples.   

## 2. Setup
<p aling="justify">
To better ilustrate the application of our framework, we will first install the R package <i></i>sp2eco</p>i>, which we provide with this repository. This can be done as following:

```r
# Install prerequisites if needed
if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")

# Install package along with the reproducible vignette
remotes::install_github("your-username/your-repo-name", build_vignettes = TRUE)
```


  
  Our framework follows a quality-assurance workflow controlling for <b>i)</b> spatial misalignments, and <b>ii)</b> labeling uncertainties. 
<p align="justified">
 To better understand this procedure, please continue below to section 2. install the needed software and how to obtain the required data, and refer you to dedicated vignette      
</p>

### How well does our solution perform?
<p align="justified">
  We evaluated the framework by comparing ecosystem-specific environmental niches inferred from the resulting reference data with those derived from independent ecosystem observations. Across multiple combinations of filtering and weighting procedures, these experiments demonstrated that combining complementary quality-assurance steps is critical for producing mapping-grade ecosystem reference data.
</p>
  

**[Package Name]** provides both the programmatic tools and a fully documented case-study vignette to solve this issue. It uses package-bundled example data combined with live external data streams to demonstrate a turn-key, reproducible workflow.

### Value to the GBIF Network
* **Innovation:** [How does your package improve on existing methods?]
* **Repeatability:** The entire workflow is packaged as a built-in vignette that compiles seamlessly on any machine.
* **Open Science:** Simplifies complex biodiversity data manipulation into reproducible steps.

---

## ⚙️ Installation
Judges can install the package engine directly from this GitHub repository. Ensure you request the vignette build during installation.


### System Dependencies
* **R Version:** >= 4.1.0
* **Core Dependencies:** `rgbif`, [list 1-2 other critical packages here]

---

## 🔄 Running the Reproducible Workflow

The complete workflow entry is self-contained within the package vignette. 

### Step 1: Open the Vignette
Once installed, run the following command in RStudio to view the complete case-study, code execution steps, and scientific narrative:

```r
library(yourPackageName)

# Open the interactive HTML workflow document
vignette("workflow_name", package = "yourPackageName")
```

### Data Sourcing & Replication Details
* **Internal Data:** The pipeline initializes using the package's built-in reference dataset (`data(example_data_name)`).
* **External Data:** The workflow automatically pings external endpoints via `rgbif` to download live, real-time occurrence records to complete the analysis.

---

## 📊 Expected Outputs & Visuals

When you execute the code blocks inside the vignette, the pipeline generates:
* **[Output 1]:** A cleaned, standardized mapping format.
* **[Output 2]:** An analytical summary map or graph. *(Tip: Drop a small markdown image snippet or screenshot of your best plot right here to catch the judges' eyes immediately).*

---

## 📄 License
This project is licensed under the [MIT / GPL-3] License - see the `LICENSE` file for details.
