# 🌱 AgriTrial Pro

<div align="center">

### Enterprise Field Trial Management Platform

**Developed during a Software Engineering Internship at Agrimatco Morocco**

---

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue)
![Supabase](https://img.shields.io/badge/Supabase-Backend-green)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Status](https://img.shields.io/badge/Status-In%20Development-success)

</div>

---

# 📖 Overview

AgriTrial Pro is an enterprise-grade digital platform designed to manage agricultural field trials from planning through evaluation and reporting.

The platform digitizes research workflows by allowing researchers, technicians, and managers to collect field data, monitor experiments, analyze observations, and generate professional reports.

This project is being developed as part of a Software Engineering Internship at **Agrimatco Morocco**.

---

# 🚀 Features

* Authentication & User Management
* Farm & Grower Management
* Experimental Station Management
* Trial Planning
* Field Evaluations
* Observation Tracking
* Photo Management
* Dashboards & Analytics
* GIS Integration (PostGIS)
* AI-Ready Database Architecture
* Automated Reports
* Audit Logs
* Role-Based Access Control (RBAC)

---

# 🏗 Project Architecture

```text
Foundation
│
├── Roles
├── Profiles
├── Regions
├── Provinces
├── Growers
├── Farms
└── Experimental Stations

Agricultural Master Data
│
├── Crops
├── Product Types
├── Trial Types
├── Witness Varieties
├── Growth Stages
├── Evaluation Criteria
└── Fruit Characteristics

Trial Management
│
├── Trials
├── Evaluations
├── Trial Photos
├── Evaluation Details
└── Evaluation Photos
```

---

# 🛠 Technology Stack

| Layer           | Technology         |
| --------------- | ------------------ |
| Mobile          | Flutter            |
| Backend         | Supabase           |
| Database        | PostgreSQL 17      |
| Authentication  | Supabase Auth      |
| Storage         | Supabase Storage   |
| Maps            | PostGIS            |
| Version Control | Git & GitHub       |
| IDE             | Visual Studio Code |

---

# 📂 Repository Structure

```text
database/
docs/
mobile/
web/
api/
assets/
```

---

# 🗄 Database

The database follows a modular migration strategy.

```
001_extensions.sql
002_enums.sql
003_domains.sql
004_functions.sql
005_trigger_functions.sql
...
099_validation.sql
```

---

# 📊 Development Roadmap

* ✅ Database Foundation
* ⏳ Core Database Tables
* ⏳ Authentication
* ⏳ Mobile Application
* ⏳ Dashboard
* ⏳ Reporting
* ⏳ AI Analytics
* ⏳ Production Deployment

---

# 📸 Screenshots

Screenshots will be added as development progresses.

```
assets/screenshots/
```

---

# 📄 Documentation

Project documentation is available in the **docs/** directory.

---

# 👨‍💻 Developer

**Hana Shaimi**

Computer Engineering Student

Cyprus International University

Software Engineering Intern – Agrimatco Morocco

---

# 📜 License

This project is licensed under the MIT License.

---
