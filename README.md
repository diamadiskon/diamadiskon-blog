# DevOps Insights Blog

A technical blog focused on DevOps practices, tools, and insights. Built with Jekyll and hosted on GitHub Pages.

## 🚀 About

This blog covers various DevOps topics including:

- **CI/CD Pipelines**: Best practices for continuous integration and deployment
- **Cloud Infrastructure**: AWS, Azure, and GCP tips and tutorials  
- **Container Technologies**: Docker, Kubernetes, and orchestration
- **Infrastructure as Code**: Terraform, CloudFormation, and more
- **Monitoring & Observability**: Tools and practices for system reliability
- **Automation**: Scripts, tools, and workflows to improve efficiency

## 🏗️ Built With

- **Jekyll** - Static site generator
- **GitHub Pages** - Hosting platform
- **Minima** - Jekyll theme
- **Markdown** - Content format

## 📝 Writing Posts

### Creating a New Post

1. Create a new file in the `_posts` directory
2. Use the naming convention: `YYYY-MM-DD-title-with-hyphens.md`
3. Add the front matter at the top:

```yaml
---
layout: post
title: "Your Post Title"
date: YYYY-MM-DD HH:MM:SS +0000
categories: [category1, category2]
tags: [tag1, tag2, tag3]
author: "Your Name"
excerpt: "A brief description of your post content."
---
```

### Post Categories

Use these categories to organize your content:
- `devops` - General DevOps practices
- `cicd` - CI/CD pipelines and automation
- `docker` - Container technologies
- `kubernetes` - Orchestration and K8s
- `terraform` - Infrastructure as Code
- `aws` / `azure` / `gcp` - Cloud platforms
- `monitoring` - Observability and monitoring
- `automation` - Scripts and automation tools

## 🛠️ Local Development

### Prerequisites

- Ruby (version 2.7 or higher)
- Bundler gem

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/diamadis-blog.git
cd diamadis-blog
```

2. Install dependencies:
```bash
bundle install
```

3. Run the development server:
```bash
bundle exec jekyll serve
```

4. Open your browser and navigate to `http://localhost:4000`

### Live Reload

The development server automatically reloads when you make changes to your content or configuration.

## 📂 Project Structure

```
diamadis-blog/
├── _config.yml          # Site configuration
├── _posts/              # Blog posts
├── _layouts/            # Custom layouts (if any)
├── _includes/           # Reusable components
├── _sass/               # Custom styles
├── assets/              # Images, CSS, JS files
├── about.md             # About page
├── index.md             # Home page
├── Gemfile              # Ruby dependencies
└── README.md            # This file
```

## 🚀 Deployment

This site is configured for automatic deployment with GitHub Pages:

1. Push your changes to the main branch
2. GitHub Pages will automatically build and deploy your site
3. Your site will be available at `https://yourusername.github.io/diamadis-blog`

### Custom Domain (Optional)

To use a custom domain:

1. Add a `CNAME` file to the root with your domain name
2. Configure DNS settings with your domain provider
3. Enable custom domain in repository settings

## ⚙️ Configuration

### Site Settings

Update `_config.yml` to customize:

- Site title and description
- Author information
- Social media links
- Navigation menu
- SEO settings

### Theme Customization

The site uses the Minima theme. You can customize:

- Colors and fonts in `_sass/minima/`
- Layouts in `_layouts/`
- Includes in `_includes/`

## 📊 Analytics

To add Google Analytics:

1. Get your tracking ID from Google Analytics
2. Add it to `_config.yml`:
```yaml
google_analytics: UA-XXXXXXXX-X
```

## 💬 Comments

To enable comments, you can integrate:
- Disqus
- Utterances (GitHub-based)
- Other Jekyll-compatible comment systems

## 🤝 Contributing

If you'd like to contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

- **Email**: your-email@example.com
- **GitHub**: [@yourusername](https://github.com/yourusername)
- **LinkedIn**: [Your Name](https://linkedin.com/in/yourusername)
- **Twitter**: [@yourusername](https://twitter.com/yourusername)

---

*Happy blogging! 🎉*
