#!/bin/bash

# DevOps Blog Setup Script
# This script helps you set up your Jekyll blog for GitHub Pages

set -e

echo "🚀 Setting up your DevOps Blog..."

# Check if required tools are installed
check_requirements() {
    echo "📋 Checking requirements..."
    
    if ! command -v ruby &> /dev/null; then
        echo "❌ Ruby is not installed. Please install Ruby 2.7 or higher."
        echo "   macOS: brew install ruby"
        echo "   Ubuntu: sudo apt-get install ruby-full"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "❌ Git is not installed. Please install Git first."
        exit 1
    fi
    
    echo "✅ Requirements satisfied"
}

# Install bundler if not present
install_bundler() {
    if ! command -v bundle &> /dev/null; then
        echo "📦 Installing Bundler..."
        gem install bundler
    fi
}

# Install Jekyll dependencies
install_dependencies() {
    echo "📦 Installing Jekyll dependencies..."
    bundle install
}

# Initialize git repository if not already done
init_git() {
    if [ ! -d ".git" ]; then
        echo "🔧 Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: DevOps blog setup"
    else
        echo "✅ Git repository already initialized"
    fi
}

# Create GitHub repository (requires GitHub CLI)
create_github_repo() {
    echo "🌐 Would you like to create a GitHub repository? (y/n)"
    read -r create_repo
    
    if [[ $create_repo =~ ^[Yy]$ ]]; then
        if command -v gh &> /dev/null; then
            echo "Enter repository name (default: diamadis-blog):"
            read -r repo_name
            repo_name=${repo_name:-diamadis-blog}
            
            echo "Creating GitHub repository..."
            gh repo create "$repo_name" --public --description "A DevOps tech blog built with Jekyll"
            
            git remote add origin "https://github.com/$(gh api user --jq .login)/$repo_name.git"
            git branch -M main
            git push -u origin main
            
            echo "✅ Repository created and pushed to GitHub"
            echo "🌐 Enable GitHub Pages in your repository settings:"
            echo "   Settings > Pages > Source: GitHub Actions"
        else
            echo "⚠️  GitHub CLI not installed. Please create repository manually:"
            echo "   1. Go to https://github.com/new"
            echo "   2. Create repository named 'diamadis-blog'"
            echo "   3. Run: git remote add origin https://github.com/USERNAME/diamadis-blog.git"
            echo "   4. Run: git push -u origin main"
        fi
    fi
}

# Customize configuration
customize_config() {
    echo "🔧 Would you like to customize the blog configuration? (y/n)"
    read -r customize
    
    if [[ $customize =~ ^[Yy]$ ]]; then
        echo "Enter your name:"
        read -r author_name
        
        echo "Enter your email:"
        read -r author_email
        
        echo "Enter your GitHub username:"
        read -r github_username
        
        echo "Enter your blog title (default: DevOps Insights):"
        read -r blog_title
        blog_title=${blog_title:-DevOps Insights}
        
        echo "Enter your blog description:"
        read -r blog_description
        
        # Update _config.yml
        sed -i.bak "s/title: DevOps Insights/title: $blog_title/" _config.yml
        sed -i.bak "s/your-email@example.com/$author_email/" _config.yml
        sed -i.bak "s/yourusername/$github_username/g" _config.yml
        
        if [ -n "$blog_description" ]; then
            sed -i.bak "s/A tech blog focused on DevOps practices.*/$blog_description/" _config.yml
        fi
        
        # Update about.md
        sed -i.bak "s/Your Name/$author_name/g" about.md
        sed -i.bak "s/yourusername/$github_username/g" about.md
        sed -i.bak "s/your-email@example.com/$author_email/" about.md
        
        # Update post authors
        find _posts -name "*.md" -exec sed -i.bak "s/Your Name/$author_name/" {} \;
        
        # Clean up backup files
        find . -name "*.bak" -delete
        
        echo "✅ Configuration updated"
    fi
}

# Start development server
start_dev_server() {
    echo "🚀 Would you like to start the development server? (y/n)"
    read -r start_server
    
    if [[ $start_server =~ ^[Yy]$ ]]; then
        echo "Starting Jekyll development server..."
        echo "📝 Your blog will be available at: http://localhost:4000"
        echo "   Press Ctrl+C to stop the server"
        bundle exec jekyll serve --livereload
    else
        echo "✅ Setup complete! Run 'bundle exec jekyll serve' to start the development server."
    fi
}

# Main setup flow
main() {
    check_requirements
    install_bundler
    install_dependencies
    init_git
    customize_config
    create_github_repo
    
    echo ""
    echo "🎉 Blog setup complete!"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Run 'bundle exec jekyll serve' to start development server"
    echo "   2. Visit http://localhost:4000 to see your blog"
    echo "   3. Edit posts in the _posts/ directory"
    echo "   4. Customize _config.yml and about.md"
    echo "   5. Push changes to GitHub to deploy automatically"
    echo ""
    echo "📚 Documentation:"
    echo "   - Jekyll: https://jekyllrb.com/docs/"
    echo "   - GitHub Pages: https://pages.github.com/"
    echo "   - Minima theme: https://github.com/jekyll/minima"
    echo ""
    
    start_dev_server
}

# Run main function
main
