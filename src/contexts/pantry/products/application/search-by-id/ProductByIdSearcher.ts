import { Service } from "diod";

import { ProductPrimitives } from "../../domain/Product";
import { ProductId } from "../../domain/ProductId";
import { ProductRepository } from "../../domain/ProductRepository";

@Service()
export class ProductByIdSearcher {
	constructor(private readonly repository: ProductRepository) {}

	async search(id: string): Promise<ProductPrimitives | null> {
		const product = await this.repository.searchById(new ProductId(id));

		return product?.toPrimitives() ?? null;
	}
}
