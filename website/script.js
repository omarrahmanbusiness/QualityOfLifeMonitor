// Mobile Menu Toggle
const mobileMenuBtn = document.getElementById('mobileMenuBtn');
const navLinks = document.querySelector('.nav-links');

mobileMenuBtn.addEventListener('click', () => {
    navLinks.classList.toggle('active');
    mobileMenuBtn.classList.toggle('active');
});

// Close mobile menu when clicking on a link
document.querySelectorAll('.nav-links a').forEach(link => {
    link.addEventListener('click', () => {
        navLinks.classList.remove('active');
        mobileMenuBtn.classList.remove('active');
    });
});

// Smooth scroll for navigation links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            const offsetTop = target.offsetTop - 80;
            window.scrollTo({
                top: offsetTop,
                behavior: 'smooth'
            });
        }
    });
});

// Navbar background on scroll
window.addEventListener('scroll', () => {
    const navbar = document.querySelector('.navbar');
    if (window.scrollY > 50) {
        navbar.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
    } else {
        navbar.style.boxShadow = '0 4px 6px -1px rgba(0, 0, 0, 0.1)';
    }
});

// Package selection function
function selectPackage(packageName) {
    const packageSelect = document.getElementById('package');
    const contactSection = document.getElementById('contact');

    // Map package names to select values
    const packageMap = {
        'Starter Package': 'starter',
        'Standard Package': 'standard',
        'Premium Package': 'premium',
        'Intensive Exam Prep': 'intensive'
    };

    // Set the selected package
    if (packageSelect && packageMap[packageName]) {
        packageSelect.value = packageMap[packageName];
    }

    // Scroll to contact section
    if (contactSection) {
        const offsetTop = contactSection.offsetTop - 80;
        window.scrollTo({
            top: offsetTop,
            behavior: 'smooth'
        });

        // Focus on the name field after scrolling
        setTimeout(() => {
            document.getElementById('name').focus();
        }, 800);
    }
}

// Contact Form Handling
const contactForm = document.getElementById('contactForm');
const formStatus = document.getElementById('formStatus');

contactForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    // Get form data
    const formData = {
        name: document.getElementById('name').value,
        email: document.getElementById('email').value,
        phone: document.getElementById('phone').value,
        package: document.getElementById('package').value,
        subject: document.getElementById('subject').value,
        message: document.getElementById('message').value
    };

    // Validate form
    if (!formData.name || !formData.email || !formData.message) {
        showFormStatus('Please fill in all required fields.', 'error');
        return;
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(formData.email)) {
        showFormStatus('Please enter a valid email address.', 'error');
        return;
    }

    // Disable submit button
    const submitBtn = contactForm.querySelector('.btn-submit');
    const originalText = submitBtn.textContent;
    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending...';

    try {
        // Simulate form submission (in production, this would send to a backend)
        await simulateFormSubmission(formData);

        // Show success message
        showFormStatus('Thank you for your message! Maria will get back to you within 24 hours.', 'success');

        // Reset form
        contactForm.reset();

        // Log to console (for demo purposes)
        console.log('Form submitted successfully:', formData);

    } catch (error) {
        showFormStatus('There was an error sending your message. Please try again or email maria@ibtutoring.com directly.', 'error');
        console.error('Form submission error:', error);
    } finally {
        // Re-enable submit button
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
});

// Show form status message
function showFormStatus(message, type) {
    formStatus.textContent = message;
    formStatus.className = `form-status ${type}`;
    formStatus.style.display = 'block';

    // Scroll to status message
    formStatus.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

    // Hide success message after 10 seconds
    if (type === 'success') {
        setTimeout(() => {
            formStatus.style.display = 'none';
        }, 10000);
    }
}

// Simulate form submission (replace with actual backend call)
function simulateFormSubmission(data) {
    return new Promise((resolve, reject) => {
        setTimeout(() => {
            // Simulate 95% success rate
            if (Math.random() > 0.05) {
                resolve({ success: true });
            } else {
                reject(new Error('Simulated error'));
            }
        }, 1500);
    });
}

// Animate elements on scroll
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// Observe all cards for animation
document.addEventListener('DOMContentLoaded', () => {
    const cards = document.querySelectorAll('.package-card, .subject-card, .testimonial-card');
    cards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = `opacity 0.6s ease ${index * 0.1}s, transform 0.6s ease ${index * 0.1}s`;
        observer.observe(card);
    });
});

// Add active state to navigation links based on scroll position
window.addEventListener('scroll', () => {
    const sections = document.querySelectorAll('section[id]');
    const scrollY = window.pageYOffset;

    sections.forEach(section => {
        const sectionHeight = section.offsetHeight;
        const sectionTop = section.offsetTop - 100;
        const sectionId = section.getAttribute('id');
        const navLink = document.querySelector(`.nav-links a[href="#${sectionId}"]`);

        if (navLink && scrollY > sectionTop && scrollY <= sectionTop + sectionHeight) {
            document.querySelectorAll('.nav-links a').forEach(link => {
                link.style.color = '';
            });
            navLink.style.color = 'var(--primary-color)';
        }
    });
});

// Form input animations
const formInputs = document.querySelectorAll('.form-group input, .form-group select, .form-group textarea');

formInputs.forEach(input => {
    input.addEventListener('focus', function() {
        this.parentElement.querySelector('label').style.color = 'var(--primary-color)';
    });

    input.addEventListener('blur', function() {
        if (!this.value) {
            this.parentElement.querySelector('label').style.color = '';
        }
    });
});

// Add hover effect to package cards
const packageCards = document.querySelectorAll('.package-card');

packageCards.forEach(card => {
    card.addEventListener('mouseenter', function() {
        this.style.borderColor = 'var(--primary-color)';
    });

    card.addEventListener('mouseleave', function() {
        if (!this.classList.contains('featured')) {
            this.style.borderColor = '';
        }
    });
});

// Console message
console.log('%cMaria\'s IB Tutoring Website', 'color: #2563eb; font-size: 20px; font-weight: bold;');
console.log('%cWebsite loaded successfully!', 'color: #10b981; font-size: 14px;');
console.log('For inquiries: maria@ibtutoring.com');
