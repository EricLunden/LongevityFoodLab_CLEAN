import SwiftUI
import UIKit

struct PetHeaderView: View {
    let pet: PetProfile?
    
    private let headerHeight: CGFloat = 300
    
    var body: some View {
        if let pet,
           let imageData = pet.imageData,
           let uiImage = UIImage(data: imageData) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: headerHeight)
                    .clipped()
                    .mask(
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color.black,
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.4),
                                Color.black.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea(edges: .top)
                
                if !pet.name.isEmpty {
                    Text(pet.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
                        .padding(.leading, 20)
                        .padding(.bottom, 6)
                }
            }
            .frame(height: headerHeight)
        }
    }
}
