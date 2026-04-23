"""
Integration tests for invoice processing system
"""
import os
import sys
import tempfile

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.storage.database import Database
from src.storage.models import Supplier
from src.invoice_processor import InvoiceProcessor
from src.classifier import SupplierClassifier, CategoryClassifier


def test_database_initialization():
    """Test database creation"""
    print("Testing database initialization...")
    
    # Use temporary database
    test_db_path = tempfile.mktemp(suffix='.db')
    db = Database(f'sqlite:///{test_db_path}')
    db.create_tables()
    
    session = db.get_session()
    
    # Create test supplier
    supplier = Supplier(
        name="Test Supplier SAS",
        normalized_name="test supplier",
        email_domain="testsupplier.com"
    )
    session.add(supplier)
    session.commit()
    
    # Verify
    retrieved = session.query(Supplier).first()
    assert retrieved.name == "Test Supplier SAS"
    
    session.close()
    
    # Cleanup
    os.unlink(test_db_path)
    
    print("✓ Database initialization test passed")


def test_supplier_classification():
    """Test supplier name normalization and classification"""
    print("Testing supplier classification...")
    
    test_db_path = tempfile.mktemp(suffix='.db')
    db = Database(f'sqlite:///{test_db_path}')
    db.create_tables()
    
    session = db.get_session()
    classifier = SupplierClassifier(session)
    
    # Test normalization
    normalized = classifier.normalize_name("Test Supplier SAS")
    assert normalized == "test supplier"
    
    # Test supplier detection
    invoice_data = {
        'supplier_name': 'Test Supplier SAS',
        'email_from': 'contact@testsupplier.com'
    }
    
    supplier = classifier.detect_supplier(invoice_data)
    assert supplier is not None
    assert supplier.normalized_name == "test supplier"
    
    session.close()
    os.unlink(test_db_path)
    
    print("✓ Supplier classification test passed")


def test_category_classification():
    """Test invoice categorization"""
    print("Testing category classification...")
    
    classifier = CategoryClassifier()
    
    # Test parts category
    invoice_data = {
        'supplier_name': 'Autodoc',
        'raw_text': 'Facture pour pare-brise et plaquette de frein',
        'email_subject': 'Facture pièces auto'
    }
    
    category = classifier.classify(invoice_data)
    assert category == 'Pièces détachées'
    
    # Test energy/location category
    invoice_data = {
        'supplier_name': 'Electricité de France',
        'raw_text': 'Facture electricite atelier carrosserie',
        'email_subject': 'Facture EDF'
    }
    
    category = classifier.classify(invoice_data)
    assert category == 'Énergie et locaux'
    
    print("✓ Category classification test passed")


def test_pdf_parsing():
    """Test PDF parsing (requires sample PDF)"""
    print("Testing PDF parsing...")
    
    processor = InvoiceProcessor()
    
    # Note: This test requires a sample PDF file
    # For now, we test the initialization
    assert processor.pdf_parser is not None
    
    print("✓ PDF parsing initialization test passed")


def run_all_tests():
    """Run all integration tests"""
    print("=" * 50)
    print("Running Integration Tests")
    print("=" * 50)
    print()
    
    try:
        test_database_initialization()
        test_supplier_classification()
        test_category_classification()
        test_pdf_parsing()
        
        print()
        print("=" * 50)
        print("All tests passed! ✓")
        print("=" * 50)
        
    except AssertionError as e:
        print(f"\n✗ Test failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    run_all_tests()
