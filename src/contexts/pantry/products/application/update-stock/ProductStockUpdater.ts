import { Service } from "diod";

import { ProductId } from "../../domain/ProductId";
import { ProductRepository } from "../../domain/ProductRepository";
import { ProductStock } from "../../domain/ProductStock";

@Service()
export class ProductStockUpdater {
	constructor(private readonly repository: ProductRepository) {}

	async update(id: string, currentStock: number): Promise<void> {
		const productId = new ProductId(id);
		const product = await this.repository.searchById(productId);

		if (!product) {
			throw new Error("PRODUCT_NOT_FOUND");
		}

		const stock = new ProductStock(currentStock);
		product.updateStock(stock);

		await this.repository.save(product);
	}
}
