import "reflect-metadata";

import { NextRequest, NextResponse } from "next/server";

import { ProductCreator } from "../../../contexts/pantry/products/application/create/ProductCreator";
import { AllProductsSearcher } from "../../../contexts/pantry/products/application/search-all/AllProductsSearcher";
import { container } from "../../../contexts/shared/infrastructure/dependency-injection/diod.config";
import { HttpNextResponse } from "../../../contexts/shared/infrastructure/http/HttpNextResponse";

const searcher = container.get(AllProductsSearcher);
const creator = container.get(ProductCreator);

export async function GET(): Promise<NextResponse> {
	const products = await searcher.searchAll();

	return HttpNextResponse.json(products);
}

export async function POST(request: NextRequest): Promise<NextResponse> {
	try {
		const body = await request.json();
		const { name, currentStock = 0 } = body;

		await creator.create(name, currentStock);

		return HttpNextResponse.created();
	} catch (error) {
		if (
			error instanceof Error &&
			error.message === "PRODUCT_ALREADY_EXISTS"
		) {
			return NextResponse.json(
				{
					error: {
						type: error.message,
						params:
							(
								error as unknown as {
									params?: Record<string, unknown>;
								}
							).params ?? {},
					},
				},
				{ status: 409 },
			);
		}
		if (error instanceof Error && error.message === "INVALID_STOCK_LEVEL") {
			return NextResponse.json(
				{
					error: {
						type: error.message,
						params:
							(
								error as unknown as {
									params?: Record<string, unknown>;
								}
							).params ?? {},
					},
				},
				{ status: 400 },
			);
		}

		return HttpNextResponse.internalServerError();
	}
}
