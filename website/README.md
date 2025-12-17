# Maria's IB Tutoring Website

A professional, fully responsive website for Maria's International Baccalaureate tutoring services, inspired by modern tutoring platforms.

## Features

### 🎨 Modern Design
- Clean, professional interface
- Responsive design (mobile, tablet, desktop)
- Smooth animations and transitions
- Beautiful gradient hero section

### 📦 Tutoring Packages
Four comprehensive package options:
1. **Starter Package** - $60/hour - Perfect for single subject focus
2. **Standard Package** - $280/5 hours - Best value with multiple subjects
3. **Premium Package** - $540/10 hours - Comprehensive coverage with IA support
4. **Intensive Exam Prep** - $1020/20 hours - Complete exam preparation

### 📚 IB Coverage
All IB subject groups covered:
- Group 1: Studies in Language & Literature
- Group 2: Language Acquisition
- Group 3: Individuals & Societies
- Group 4: Sciences
- Group 5: Mathematics
- Group 6: The Arts
- Core Components: Extended Essay, TOK, CAS

### ✨ Key Features
- **Fixed Navigation Bar** - Easy access to all sections
- **Hero Section** - Eye-catching introduction with clear CTAs
- **Package Cards** - Interactive pricing cards with hover effects
- **Subject Grid** - Comprehensive display of all IB subjects offered
- **About Section** - Professional profile with credentials
- **Testimonials** - Student success stories
- **Contact Form** - Functional form with validation
- **Mobile Menu** - Hamburger menu for mobile devices
- **Smooth Scrolling** - Enhanced user experience
- **Form Validation** - Client-side validation for contact form

## Technical Stack

- **HTML5** - Semantic markup
- **CSS3** - Modern styling with CSS Grid and Flexbox
- **Vanilla JavaScript** - No dependencies, fast loading
- **Google Fonts** - Inter font family
- **Responsive Design** - Mobile-first approach

## File Structure

```
website/
├── index.html      # Main HTML file
├── styles.css      # CSS styling
├── script.js       # JavaScript functionality
└── README.md       # This file
```

## How to Use

### Option 1: Open Directly
Simply open `index.html` in any modern web browser.

### Option 2: Local Server (Recommended)
For the best experience, serve the website using a local server:

#### Using Python 3:
```bash
cd website
python3 -m http.server 8000
```
Then open http://localhost:8000 in your browser.

#### Using Node.js (with npx):
```bash
cd website
npx serve
```

#### Using PHP:
```bash
cd website
php -S localhost:8000
```

## Customization

### Update Contact Information
Edit `index.html` and find the contact section:
- Change email address from `maria@ibtutoring.com` to your actual email
- Update phone number if needed
- Modify response times and availability

### Adjust Pricing
In `index.html`, locate the packages section and update:
- Package prices
- Package features
- Package names

### Change Colors
Edit `styles.css` and modify the CSS variables in `:root`:
```css
:root {
    --primary-color: #2563eb;    /* Main brand color */
    --secondary-color: #10b981;  /* Accent color */
    --accent-color: #f59e0b;     /* Highlight color */
}
```

### Add Your Photo
Replace the placeholder emoji in the About section with an actual image:
```html
<!-- Replace this: -->
<div class="image-placeholder">
    <span>👩‍🏫</span>
</div>

<!-- With this: -->
<img src="path/to/your/photo.jpg" alt="Maria" style="width: 280px; height: 280px; border-radius: 50%; object-fit: cover;">
```

### Form Integration
The contact form currently simulates submission. To make it functional:

#### Option 1: Using Formspree
1. Sign up at https://formspree.io/
2. Get your form endpoint
3. Update the form in `script.js`:
```javascript
// Replace simulateFormSubmission with:
async function submitForm(data) {
    const response = await fetch('https://formspree.io/f/YOUR_FORM_ID', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
    return response.json();
}
```

#### Option 2: Using EmailJS
1. Sign up at https://www.emailjs.com/
2. Set up your email service
3. Follow their integration guide

#### Option 3: Backend API
Integrate with your own backend API endpoint.

## Browser Compatibility

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Performance

- Lightweight (no framework dependencies)
- Fast loading time
- Optimized images (when added)
- Minimal external dependencies (only Google Fonts)

## Deployment Options

### GitHub Pages
1. Create a new repository
2. Push the website folder contents
3. Enable GitHub Pages in repository settings
4. Your site will be live at `https://yourusername.github.io/repository-name`

### Netlify
1. Sign up at https://www.netlify.com/
2. Drag and drop the website folder
3. Your site will be live instantly with a custom URL

### Vercel
1. Sign up at https://vercel.com/
2. Import your repository
3. Deploy with one click

### Traditional Hosting
Upload all files to your web hosting provider via FTP/SFTP.

## SEO Optimization

The website includes:
- Semantic HTML5 markup
- Meta descriptions
- Proper heading hierarchy
- Alt text for images (when added)
- Mobile-responsive design

To improve SEO further:
- Add more meta tags
- Create a sitemap.xml
- Add structured data (JSON-LD)
- Optimize images
- Add robots.txt

## Accessibility

The website follows accessibility best practices:
- Semantic HTML
- Proper heading hierarchy
- Keyboard navigation support
- Focus indicators
- Color contrast compliance
- ARIA labels (where needed)

## Future Enhancements

Possible additions:
- Blog section for IB tips and resources
- Student portal/login area
- Online booking calendar
- Payment integration
- Video introduction
- Resource download section
- FAQ section
- Live chat widget

## Support

For questions or customization help, refer to:
- HTML: https://developer.mozilla.org/en-US/docs/Web/HTML
- CSS: https://developer.mozilla.org/en-US/docs/Web/CSS
- JavaScript: https://developer.mozilla.org/en-US/docs/Web/JavaScript

## License

This website is created for Maria's personal tutoring business. Feel free to modify and customize as needed.

---

**Built with care for IB student success** 📚✨
