# Book Scanner App - Comprehensive Test Plan

## Version 1.0 Testing Checklist

### 1. Authentication & Security
- [ ] Biometric authentication (Face ID/Touch ID) works
- [ ] App requires authentication on launch
- [ ] Authentication persists across app restarts
- [ ] Authentication fails gracefully with error message

### 2. Camera & Photo Library
- [ ] Camera button opens camera interface
- [ ] Photo library button opens photo picker
- [ ] Selected image displays correctly
- [ ] Image can be cleared/reset
- [ ] Camera permissions requested properly
- [ ] Photo library permissions requested properly

### 3. Scanning Features

#### OCR Scanning
- [ ] OCR mode processes images correctly
- [ ] OCR detects book titles
- [ ] OCR detects authors (single and multiple)
- [ ] OCR detects publishers
- [ ] OCR handles vertical text (rotated images)
- [ ] OCR isolates individual book spines
- [ ] OCR preserves original case formatting

#### AI Scanning
- [ ] AI mode processes images correctly
- [ ] AI detects book titles
- [ ] AI detects authors (single and multiple)
- [ ] AI detects publishers
- [ ] AI handles vertical text (rotated images)
- [ ] AI isolates individual book spines using rectangle detection
- [ ] AI falls back to text recognition if rectangle detection fails

#### Both (OCR + AI)
- [ ] Both modes run simultaneously
- [ ] Results from both modes are displayed
- [ ] Comparison view shows differences
- [ ] User can select which results to save

### 4. Book Recognition Accuracy
- [ ] Multiple authors detected correctly (e.g., "Author1 AND Author2")
- [ ] Authors with "&" separator detected
- [ ] Authors with comma separator detected
- [ ] Long titles handled correctly
- [ ] Publisher names identified correctly
- [ ] Books with missing information handled gracefully

### 5. Library Management (CRUD)

#### Create
- [ ] Manual book entry form works
- [ ] All fields can be filled (title, author, publisher, ISBN, notes)
- [ ] Image can be added to manual entry
- [ ] Validation works (required fields)
- [ ] ISBN format validation works
- [ ] Book saves correctly to database

#### Read
- [ ] Book list displays all books
- [ ] Book count shows correctly
- [ ] Search functionality works (title, author, publisher, ISBN)
- [ ] Sorting works (Date, Title, Author, Publisher)
- [ ] Sort order works (Ascending/Descending)
- [ ] Book detail view shows all information
- [ ] Book images display correctly

#### Update
- [ ] Book details can be edited
- [ ] Book image can be changed
- [ ] Book image can be removed
- [ ] Changes save correctly
- [ ] Validation works on edit

#### Delete
- [ ] Single book deletion works
- [ ] Batch deletion works (edit mode)
- [ ] Delete confirmation dialog appears
- [ ] Deleted books are removed from database
- [ ] List updates after deletion

### 6. Amazon Integration
- [ ] Amazon lookup button works
- [ ] Loading state shows during lookup
- [ ] Price information retrieved
- [ ] Amazon URL retrieved
- [ ] Link to Amazon works
- [ ] Handles lookup failures gracefully
- [ ] Validates books with Amazon data

### 7. Export Functionality
- [ ] Export to CSV works
- [ ] CSV contains all book data
- [ ] CSV format is correct
- [ ] Export shares file correctly
- [ ] All books included in export

### 8. Settings
- [ ] Scan method selection works (OCR/AI/Both)
- [ ] Compare results toggle works
- [ ] Settings persist across app restarts
- [ ] Amazon API credentials can be entered (stubbed)

### 9. UI/UX
- [ ] All tabs accessible
- [ ] Navigation works correctly
- [ ] Loading states display properly
- [ ] Error messages are user-friendly
- [ ] Version number displays on home screen
- [ ] Accessibility features work (VoiceOver)
- [ ] App works on different screen sizes

### 10. Performance & Stability
- [ ] App handles large images
- [ ] Processing doesn't block UI
- [ ] Memory usage is reasonable
- [ ] No crashes during normal use
- [ ] Background processing works
- [ ] Image caching works

### 11. Error Handling
- [ ] Network errors handled gracefully
- [ ] Image processing errors handled
- [ ] Database errors handled
- [ ] Invalid input validated
- [ ] Error messages are clear and actionable

### 12. Data Persistence
- [ ] Books persist after app restart
- [ ] Settings persist after app restart
- [ ] Images stored correctly
- [ ] Data integrity maintained

## Test Execution Notes

### Test Images Needed
- Bookshelf with multiple books (horizontal spines)
- Bookshelf with vertical spines (portrait orientation)
- Books with multiple authors
- Books with various title/author formats
- Single book image
- Poor quality image (for error handling)

### Test Scenarios
1. **Happy Path**: Scan bookshelf → Review results → Save → View in library
2. **Manual Entry**: Add book manually → Edit → Delete
3. **Search & Filter**: Add multiple books → Search → Sort
4. **Export**: Add books → Export to CSV → Verify content
5. **Error Cases**: Invalid image → Network failure → Invalid input

## Known Issues to Verify
- [ ] Multiple author detection accuracy
- [ ] Book spine isolation accuracy
- [ ] Image rotation for vertical text
- [ ] Amazon lookup reliability
